#define _GNU_SOURCE
#include <assert.h>
#include <pthread.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/sysinfo.h>
#include <sched.h>
//#include <x86intrin.h>
#include "rerocc_scheduler.h"
#include "helpers.h"
#include "queue.h"
#include "queueagain.h"
#include "rqueue.h"
#include "atomic_defs.h"

#ifndef USE_PRINTS
#define printf(...) (0)
#endif

#ifndef KEEP_ASSERTS
#define assert(x) (x)
#endif

static inline uint64_t get_cur_ns_raw(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
  return (1e9 * ts.tv_sec) + ts.tv_nsec;
}

static inline uint64_t get_cur_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_BOOTTIME, &ts);
  return (1e9 * ts.tv_sec) + ts.tv_nsec;
}

#define MAX_PAYLOADS (1000)
typedef struct {
  bool filled;
  size_t len; // len given by CPU serialization
  uint64_t time_ns; // time to serialize on the CPU
} entry_t;
entry_t proto_ser_entries[MAX_PAYLOADS];

static size_t cpu_proto_runtime_ns(size_t mid, size_t size) {
  entry_t* entry = &proto_ser_entries[mid];
  return (ATOMIC_READ(entry->time_ns) * size) / entry->len;
}

void update_cpu_proto_runtime_tput(size_t mid, size_t size, size_t duration) {
  int _b = 0;
  do {
    size_t old = ATOMIC_READ(proto_ser_entries[mid].time_ns);
    _b = ATOMIC_CAS(proto_ser_entries[mid].time_ns, old, (old + duration) / 2); // get the avg. of the two
  } while (__builtin_expect(!_b, 0));
  assert(ATOMIC_READ(proto_ser_entries[mid].len) == size);
  printf("Updating prediction %d with new time %ldns (input: %ldns)\n", mid, ATOMIC_READ(proto_ser_entries[mid].time_ns), duration);
}

void SchedSetEstimatedCPUTput(size_t id, size_t len, uint64_t time_ns) {
  assert(id < MAX_PAYLOADS);

  entry_t* entry = &proto_ser_entries[id];
  if (entry->filled) {
    return; // keep old entry
  }

  entry->filled = true;
  entry->len = len;
  entry->time_ns = time_ns;

  fprintf(stderr, "Adding est. CPU throughput: uniqid:%lu, len:%d, timens:%lu\n", id, len, time_ns);
}

#define MAX_STATIC_ACCS (1000)

size_t max_protobuf_ser_ids;
uint64_t protobuf_ser_accids[MAX_STATIC_ACCS];
queue_t acc_running_q[MAX_STATIC_ACCS];
queueagain_t acc_running_qagain[MAX_STATIC_ACCS];
bool acc_busy[MAX_STATIC_ACCS]; // HACK: fake accelerator busy or not

// fill arr + len with arr/len of the accelerator wanted
static inline void get_accids(acc_type_t acc_type, uint64_t** arr, uint64_t* len) {
  *arr = protobuf_ser_accids;
  *len = max_protobuf_ser_ids;
}

pthread_mutex_t main_mutex;
pthread_cond_t main_cond = PTHREAD_COND_INITIALIZER;
pthread_mutex_t queues_mutex;
pthread_cond_t queues_cond = PTHREAD_COND_INITIALIZER;
pthread_spinlock_t queues_spinlock;
pthread_spinlock_t queue_balance_spinlock;

FILE *fp;

#ifndef MAX_ACCS
#define MAX_ACCS (2)
#endif

#ifndef RQUEUE_SIZE
#define RQUEUE_SIZE (100)
#endif

rqueue_t* acc_running_rq[MAX_STATIC_ACCS];

// scheduler can be shared between threads of a same process (client/server in 1 binary running localhost)
// scheduler can be shared between threads of different process (client/server in 2 binaries running as localhost)
//   not an option in this case for us
// otherwise scheduler is on two separate machines w/ different accelerators (no sharing necessary)
//
// thus we can default to just synch. between threads of the same process
void init_scheduler(void) {
#ifdef USE_PRINTS
  // unbuffer stdout
  setbuf(stdout, NULL);
#endif

  // ok to clear twice (since we expect server will be setup before client)
  for (size_t i = 0; i < MAX_STATIC_ACCS; ++i) {
    q_init(&acc_running_q[i]);
    qagain_init(&acc_running_qagain[i]);
    acc_running_rq[i] = rqueue_create(RQUEUE_SIZE, RQUEUE_MODE_BLOCKING);
    acc_busy[i] = false;
  }

  max_protobuf_ser_ids = MAX_ACCS;
  for (size_t i = 0; i < MAX_ACCS; ++i) {
    protobuf_ser_accids[i] = i;
  }

  fp = fopen("sched.txt", "w");
  if (fp == NULL) {
    printf("SCHED: unable to open file\n");
    exit(1);
  }

  int rc;

  pthread_mutexattr_t attr;
  rc = pthread_mutexattr_init(&attr);
  if (rc != 0) {
      perror("pthread_mutexattr_init failed");
      exit(1);
  }

#if defined(ADAPTIVE_LOCK)
  rc = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ADAPTIVE_NP);
  if (rc != 0) {
      perror("pthread_mutexattr_settype failed");
      pthread_mutexattr_destroy(&attr);
      exit(1);
  }
#endif

  rc = pthread_mutex_init(&queues_mutex, &attr);
  if (rc != 0) {
      perror("pthread_mutex_init failed");
      pthread_mutexattr_destroy(&attr);
      exit(1);
  }
  rc = pthread_mutex_init(&main_mutex, &attr);
  if (rc != 0) {
      perror("pthread_mutex_init failed");
      pthread_mutexattr_destroy(&attr);
      exit(1);
  }

  rc = pthread_mutexattr_destroy(&attr);
  if (rc != 0) {
      perror("pthread_mutexattr_destroy failed");
      exit(1);
  }

  rc = pthread_spin_init(&queues_spinlock, PTHREAD_PROCESS_SHARED);
  if (rc != 0) {
      perror("pthread_spin_init failed");
      exit(1);
  }

  rc = pthread_spin_init(&queue_balance_spinlock, PTHREAD_PROCESS_SHARED);
  if (rc != 0) {
      perror("pthread_spin_init failed");
      exit(1);
  }

#ifdef PIN_CPU
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  // pin to 1st 16c of the system (hopefully physical and not threads)
  for (size_t i = 0; i < 16; ++i) {
    CPU_SET(i, &cpuset);
  }
  sched_setaffinity(0/*current thread*/, sizeof(cpu_set_t), &cpuset); // bind current thread to current cpu
#endif
}

// ---

static bool is_queue_empty(uint64_t* accids, size_t accids_len, size_t* empty_queue_id) {
  for (size_t i = 0; i < accids_len; ++i) {
    printf("SCHED: testing queueid:%lu sz:%lu\n", accids[i], q_size(&acc_running_q[accids[i]]));
    if (q_empty(&acc_running_q[accids[i]])) {
      printf("SCHED: found empty queueid:%lu\n", accids[i]);
      *empty_queue_id = accids[i];
      return true;
    }
  }
  return false;
}

static bool is_queue_empty_busywait(uint64_t* accids, size_t accids_len, size_t* empty_queue_id) {
  for (size_t i = 0; i < accids_len; ++i) {
    printf("SCHED: testing queueid:%lu sz:%lu\n", accids[i], q_size(&acc_running_q[accids[i]]));

    if (q_empty(&acc_running_q[accids[i]])) {
      printf("SCHED: found empty queueid:%lu\n", accids[i]);
      *empty_queue_id = accids[i];
      return true;
    }
  }
  return false;
}

static bool is_ready_to_acquire(uint64_t* accids, size_t accids_len, size_t* ready_queue_id, metadata_t* in_metadata) {
  elem_t peek_metadata;
  for (size_t i = 0; i < accids_len; ++i) {
    if (q_peek(&acc_running_q[accids[i]], &peek_metadata)) {
      printf("SCHED: peek queueid:%lu peeked:%lx in:%lx\n", accids[i], peek_metadata.metadata, in_metadata->tid);
      if (peek_metadata.metadata == in_metadata->tid) {
        printf("SCHED: metadata match\n");
        assert(!peek_metadata.running); // should be not running
        *ready_queue_id = accids[i];
        return true;
      }
    }
  }
  return false;
}

// queue elem = metadata_ptr (assumed to be aligned to 16), where lowest bit 0 or 1 is running or not
// if queue = empty -> then nothing running
// if queue has elem -> that elem is either running or is up next to run
// if queue has multiple elems -> 1 elem is same as above, next ones are waiting
bool grab_accelerator_queued(metadata_t* in_metadata, pthread_cond_t* queues_cond, bool* previously_enqueued, uint64_t* accids, size_t accids_len, int32_t* out_cfgid, size_t* out_accid) {
  size_t cur_accid;
  bool any_queue_empty = is_queue_empty(accids, accids_len, &cur_accid);

  bool was_waiting = false;
  if (!any_queue_empty) {
    printf("SCHED: no queues free\n");

    // only enqueue if it already wasn't enqueued (only want to wait once)
    if (!(*previously_enqueued)) {
      printf("SCHED: hasn't been enqueued yet\n");
      // fill the queue with least amt of work i.e. proto_ser_entries
      // TODO: could probably have a better heuristic
      size_t best_queue_accid = accids[0];
      size_t cur_min = MAX_QUEUE_SIZE;
      for (size_t i = 0; i < accids_len; ++i) {
        size_t size = q_size(&acc_running_q[accids[i]]);
        printf("SCHED: curmin:%d queueid:%d queuesz:%d\n", cur_min, accids[i], size);
        if (size < cur_min) {
          cur_min = size;
          best_queue_accid = accids[i];
        }
      }

      printf("SCHED: attempt enqueue into queue:%d for waiting\n", best_queue_accid);
      elem_t e;
      e.metadata = (uint64_t)in_metadata & ~METADATA_MASK;
      if (q_enqueue(&acc_running_q[best_queue_accid], e)) {
        printf("SCHED: success, enqueued for waiting\n");
        *previously_enqueued = true;
      } else {
        printf("SCHED: unable to enqueue for waiting\n");
      }

      return false;
    } else {
      printf("SCHED: was already enqueued\n"); // so check the 1st element
      was_waiting = is_ready_to_acquire(accids, accids_len, &cur_accid, in_metadata);
      if (!was_waiting) {
        printf("SCHED: this thread not waiting\n"); // elem didn't get to front of the line
        return false;
      }
    }
  }

  // either a q is empty (i.e. accel not in use) or a q's 1st element is waiting for accel and just needs to be allocated

  *out_cfgid = -1;

  printf("SCHED: acquiring accid:%lu\n", cur_accid);
  assert(!acc_busy[cur_accid]);
  acc_busy[cur_accid] = true;
  *out_accid = cur_accid;

  if (!was_waiting) {
    printf("SCHED: enqueuing queueid:%lu\n", cur_accid);
    elem_t e;
    e.metadata = (uint64_t)in_metadata | METADATA_MASK;
    assert(q_enqueue(&acc_running_q[cur_accid], e));
  } else {
    printf("SCHED: poke queueid:%lu to %lx\n", cur_accid, (uint64_t)in_metadata | METADATA_MASK);
    elem_t peeked_metadata;
    assert(q_peek(&acc_running_q[cur_accid], &peeked_metadata));
    assert(peeked_metadata.metadata == (uint64_t)in_metadata);
    peeked_metadata.metadata = (uint64_t)in_metadata | METADATA_MASK;
    assert(q_poke(&acc_running_q[cur_accid], peeked_metadata));
  }

  return true;
}

void pthread_cond_wait_wrapper(const char* prefix, pthread_cond_t *restrict cond, pthread_mutex_t *restrict mutex) {
  pthread_cond_wait(cond, mutex);
  // struct timespec timeout;
  // clock_gettime(CLOCK_BOOTTIME, &timeout);
  // timeout.tv_sec += 30;
  // if (pthread_cond_timedwait(cond, mutex, &timeout)) {
  //   printf("TIMEOUT:%s: tid:%lu cpuid:%lu\n", prefix, pthread_self(), sched_getcpu());
  //   exit(1);
  // }
}

bool grab_accelerator(metadata_t* in_metadata, uint64_t* accids, size_t accids_len, int32_t* out_cfgid, size_t* out_accid) {
  *out_cfgid = -1;

  bool acq = false;
  for (size_t i = 0; i < accids_len; ++i) {
    printf("SCHED: attempting acquire of %lu\n", accids[i]);
    uint64_t accid = accids[i];
    if (!acc_busy[accid]) {
      *out_accid = accid;
      acc_busy[accid] = true;
      acq = true;
      printf("SCHED: acquired accid:%d to cfgid:%d\n", *out_accid, -1);
      break;
    }
  }

  return acq;
}

//#define USE_CYCLES

#ifdef USE_CYCLES
#define CYCLES_TO_NS 3
#else
#define CYCLES_TO_NS 1
#endif

uint64_t get_est_acc_runtime_ns(metadata_t* metadata) {
  return cpu_proto_runtime_ns(metadata->mid, metadata->size) / (ACC_SPEEDUP * CYCLES_TO_NS);
}

uint64_t get_est_cpu_runtime_ns(metadata_t* metadata) {
  return cpu_proto_runtime_ns(metadata->mid, metadata->size) / CYCLES_TO_NS;
}

#ifdef FCFS_RUNTIME_SKIP
  /*
   * if prev_enqueued:
   *   if was_waiting:
   *     change to running, break out of loop
   *   else:
   *     continue loop
   * else:
   *   if a queue is empty:
   *     enqueue into empty queue, change to running, break out of loop
   *   else:
   *     all queues have elements
   *     choose queue that is "best" to enqueue into it (only if it makes sense w.r.t running on CPU)
   */
bool grab_accelerator_queued_runtime(metadata_t* in_metadata, pthread_cond_t* queues_cond, bool* previously_enqueued, bool* run_on_cpu, uint64_t* accids, size_t accids_len, int32_t* out_cfgid, size_t* out_accid) {
  uint64_t cur_time_ns = get_cur_ns();

  if (*previously_enqueued) {
    printf("SCHED: tid:%ld: previously enqueued\n", in_metadata->tid);
    size_t cur_accid;
    if (is_ready_to_acquire(accids, accids_len, &cur_accid, in_metadata)) {
      printf("SCHED: tid:%ld: in front of queue, start running on q%lu\n", in_metadata->tid, cur_accid);

      // check it's not in any queue already
#ifdef KEEP_ASSERTS
      for (size_t i = 0; i < accids_len; ++i) {
        if (accids[i] != cur_accid) {
          printf("SCHED: tid:%ld: check %ld q for tid\n", in_metadata->tid, accids[i]);
          assert(!q_found(&acc_running_q[accids[i]], in_metadata->tid));
        }
      }
#endif

      // modify front of queue
      elem_t peeked_metadata;
      assert(q_peek(&acc_running_q[cur_accid], &peeked_metadata));
      assert(peeked_metadata.metadata == in_metadata->tid);
      peeked_metadata.metadata = in_metadata->tid;
      peeked_metadata.running = true;
      peeked_metadata.ns_since_epoch = cur_time_ns;
      assert(q_poke(&acc_running_q[cur_accid], peeked_metadata));
      pthread_cond_broadcast(queues_cond);

      // modify acc busy
      assert(!acc_busy[cur_accid]);
      acc_busy[cur_accid] = true;
      *out_accid = cur_accid;

      return true;
    } else {
      printf("SCHED: tid:%ld: waiting in queue\n", in_metadata->tid); // elem didn't get to front of the line
      return false;
    }
  } else {
    printf("SCHED: tid:%ld: not previously enqueued\n", in_metadata->tid);
    uint64_t est_acc_runtime_ns = get_est_acc_runtime_ns(in_metadata);

    size_t cur_accid;
    if (is_queue_empty(accids, accids_len, &cur_accid)) {
      printf("SCHED: tid:%ld: putting in empty queue q%lu\n", in_metadata->tid, cur_accid);

#ifdef KEEP_ASSERTS
      // check it's not in any queue already
      for (size_t i = 0; i < accids_len; ++i) {
        printf("SCHED: tid:%ld: check %ld q for tid\n", in_metadata->tid, accids[i]);
        assert(!q_found(&acc_running_q[accids[i]], in_metadata->tid));
      }
#endif

#ifdef KEEP_ASSERTS
      // put into queue
      assert(q_empty(&acc_running_q[cur_accid]));
#endif
      elem_t e;
      e.ns_since_epoch = cur_time_ns;
      e.est_acc_ns = est_acc_runtime_ns;
      e.metadata = in_metadata->tid;
      e.running = true;
      assert(q_enqueue(&acc_running_q[cur_accid], e));
      pthread_cond_broadcast(queues_cond);

      // modify acc busy
      assert(!acc_busy[cur_accid]);
      acc_busy[cur_accid] = true;
      *out_accid = cur_accid;

      return true;
    } else {
      printf("SCHED: tid:%ld: all queues has some elements (maybe enqueue or skip acc)\n", in_metadata->tid);

      // choose best queue (if wanting to run on acc)
      bool run_on_acc = false;
      size_t best_queue_accid = accids[0];
      uint64_t cur_min = UINT64_MAX;
      uint64_t est_cpu_runtime_ns = get_est_cpu_runtime_ns(in_metadata);
      for (size_t i = 0; i < accids_len; ++i) {
        elem_t e;
        assert(q_peek(&acc_running_q[accids[i]], &e));
        bool is_running = e.running;
        uint64_t acc_block_for_at_least_ns = q_sum(&acc_running_q[accids[i]]);
        uint64_t running_or_nextup_start_ns = e.ns_since_epoch;
        uint64_t time_since_first_acc_started_ns = cur_time_ns - running_or_nextup_start_ns;

         // only subtract if is actually running otherwise assume the worst
        int64_t ns_left_for_all_accs = acc_block_for_at_least_ns - (is_running ? time_since_first_acc_started_ns : 0);
        ns_left_for_all_accs = (ns_left_for_all_accs > 0 ? ns_left_for_all_accs : 0);
        printf("SCHED: tid:%ld: q%lu is_running:%d sum:%ld timesincestart:%ld nsleft:%ld\n", in_metadata->tid, accids[i], is_running, acc_block_for_at_least_ns, time_since_first_acc_started_ns, ns_left_for_all_accs);

        if (est_cpu_runtime_ns > (ns_left_for_all_accs + est_acc_runtime_ns)) {
          printf("SCHED: tid:%ld: cpu expected to take longer than accs: cpu:%ld accs:%ld\n", in_metadata->tid, est_cpu_runtime_ns, ns_left_for_all_accs + est_acc_runtime_ns);
          run_on_acc = true;
          // find the accid queue that would be fastest
          if (est_acc_runtime_ns < cur_min) {
            cur_min = est_acc_runtime_ns;
            best_queue_accid = accids[i];
            printf("SCHED: tid:%ld: best_queue_accid:%d\n", in_metadata->tid, best_queue_accid);
          }
        }
      }

      // here run_on_acc, best_queue_accid set
      if (run_on_acc) {
        // enqueue on best_queue_accid's queue to wait (since we are guaranteed that something is before this)
        // block waiting for a change in the queue
        printf("SCHED: tid:%ld: want to run on acc, but need to wait (attempt enqueue into q%d)\n", in_metadata->tid, best_queue_accid);

#ifdef KEEP_ASSERTS
        // check it's not in any queue already
        for (size_t i = 0; i < accids_len; ++i) {
          printf("SCHED: tid:%ld: check %ld q for tid\n", in_metadata->tid, accids[i]);
          assert(!q_found(&acc_running_q[accids[i]], in_metadata->tid));
        }
#endif

        elem_t e;
        e.ns_since_epoch = cur_time_ns;
        e.est_acc_ns = est_acc_runtime_ns;
        e.metadata = in_metadata->tid;
        e.running = false;
        if (q_enqueue(&acc_running_q[best_queue_accid], e)) {
          pthread_cond_broadcast(queues_cond);
          printf("SCHED: tid:%ld: success, enqueued for waiting\n", in_metadata->tid);
          *previously_enqueued = true;
        } else {
          printf("SCHED: tid:%ld: unable to enqueue for waiting\n", in_metadata->tid);
        }

        return false;
      } else {
        printf("SCHED: tid:%ld: choose to run on cpu\n", in_metadata->tid);
        *run_on_cpu = true;

        return true;
      }
    }
  }

  assert(false && "SHOULD NOT GET HERE");
}
#endif


#ifdef FCFS_RUNTIME_SKIP_OPT
  /*
   *   if a queue is empty:
   *     enqueue into empty queue, change to running, break out of loop
   *   else:
   *     all queues have elements
   *     choose queue that is "best" to enqueue into it (only if it makes sense w.r.t running on CPU),
   *        enqueue means putting the cond_var into the queue and also stalling on it (if woken up then it is in the front of the q)
   */

// returns if running on cpu
bool grab_accelerator_queued_runtime_opt(metadata_t* in_metadata, uint64_t* accids, size_t accids_len, size_t* out_accid) {
  uint64_t est_acc_runtime_ns = get_est_acc_runtime_ns(in_metadata);

  size_t cur_accid;
  if (is_queue_empty(accids, accids_len, &cur_accid)) {
    printf("SCHED: tid:%ld: putting in empty queue q%lu\n", in_metadata->tid, cur_accid);

// #ifdef KEEP_ASSERTS
//     // check it's not in any queue already
//     for (size_t i = 0; i < accids_len; ++i) {
//       printf("SCHED: tid:%ld: check %ld q for tid\n", in_metadata->tid, accids[i]);
//       assert(!q_found(&acc_running_q[accids[i]], in_metadata->tid));
//     }
// #endif

// #ifdef KEEP_ASSERTS
//     // put into queue
//     assert(q_empty(&acc_running_q[cur_accid]));
// #endif

    elem_t e;
    e.ns_since_epoch = 0;//get_cur_ns();
    e.est_acc_ns = est_acc_runtime_ns;// + 500; // AJG: TODO: add fudge factor (time to enqueue, do other stuff, etc), context swtich ~1us so add 1/2 of that?
    //e.metadata = in_metadata->tid;
    e.running = true;
    pthread_cond_t* thread_cond; // unused
    assert(q_enqueue_ptr(&acc_running_q[cur_accid], &e, &thread_cond));

    // modify acc busy (i.e. running on acc)
    assert(!acc_busy[cur_accid]);
    acc_busy[cur_accid] = true;
    *out_accid = cur_accid;

    return false;
  } else {
    printf("SCHED: tid:%ld: all queues have elements (maybe enqueue or skip acc)\n", in_metadata->tid);

    // choose best queue (if wanting to run on acc)
    bool run_on_acc = false;
    size_t best_queue_accid = accids[0];
    uint64_t cur_min = UINT64_MAX;
    uint64_t est_cpu_runtime_ns = get_est_cpu_runtime_ns(in_metadata);
    for (size_t i = 0; i < accids_len; ++i) {
      elem_t e;
      assert(q_peek(&acc_running_q[accids[i]], &e));
      uint64_t acc_block_for_at_least_ns = q_sum(&acc_running_q[accids[i]]);

      // AJG: this is always assuming the worst case (all tasks need to run)
      // but is also assuming that scheduling, etc takes 0 time
      int64_t ns_left_for_all_accs = (acc_block_for_at_least_ns > 0 ? acc_block_for_at_least_ns : 0);
      printf("SCHED: tid:%ld: q%lu nsleft(worstcase):%ld\n", in_metadata->tid, accids[i], ns_left_for_all_accs);

      if (est_cpu_runtime_ns > (ns_left_for_all_accs + est_acc_runtime_ns)) {
        printf("SCHED: tid:%ld: cpu expected to take longer than accs: cpur:%ld accr:%ld accr+remaining:%ld\n", in_metadata->tid, est_cpu_runtime_ns, est_acc_runtime_ns, ns_left_for_all_accs + est_acc_runtime_ns);
        run_on_acc = true;
        // find the accid queue that would be fastest
        if (est_acc_runtime_ns < cur_min) {
          cur_min = est_acc_runtime_ns;
          best_queue_accid = accids[i];
          printf("SCHED: tid:%ld: best_queue_accid:%d\n", in_metadata->tid, best_queue_accid);
        }
      }
    }

    // here run_on_acc, best_queue_accid set
    if (run_on_acc) {
      // enqueue on best_queue_accid's queue to wait (since we are guaranteed that something is before this)
      // block waiting for a change in the queue
      printf("SCHED: tid:%ld: want to run on acc, but need to wait (attempt enqueue into q%d)\n", in_metadata->tid, best_queue_accid);

// #ifdef KEEP_ASSERTS
//       // check it's not in any queue already
//       for (size_t i = 0; i < accids_len; ++i) {
//         printf("SCHED: tid:%ld: check %ld q for tid\n", in_metadata->tid, accids[i]);
//         assert(!q_found(&acc_running_q[accids[i]], in_metadata->tid));
//       }
// #endif

      if (q_full(&acc_running_q[best_queue_accid])) {
        printf("SCHED: tid:%ld: blocking, queue is full\n", in_metadata->tid);
        pthread_cond_wait(acc_running_q[best_queue_accid].full_cond, &queues_mutex);
        printf("SCHED: tid:%ld: unblocking, queue has space\n", in_metadata->tid);
      }

      // TODO: enqueue gives a ptr which you can fill (also access the cond var)
      elem_t e;
      e.est_acc_ns = est_acc_runtime_ns;// + 500; // AJG: see fudge factor comment above
      //e.metadata = in_metadata->tid;
      e.running = false;
      pthread_cond_t* thread_cond;
      assert(q_enqueue_ptr(&acc_running_q[best_queue_accid], &e, &thread_cond));
      printf("SCHED: tid:%ld: success, enqueued for waiting, blocking\n", in_metadata->tid);
      pthread_cond_wait(thread_cond, &queues_mutex);
      printf("SCHED: tid:%ld: success, acc should be free and ready to run this thread\n", in_metadata->tid);
      // i.e. this element is now at the front (need to change running to true, and set time)
// #ifdef KEEP_ASSERTS
//       assert(q_peek(&acc_running_q[best_queue_accid], &e));
//       //assert(e.metadata == in_metadata->tid);
//       assert(e.running == false);
// #endif
      //assert(q_poke_running(&acc_running_q[best_queue_accid], get_cur_ns())); // updates running and time at same time (i.e. acc started)
      assert(q_poke_running(&acc_running_q[best_queue_accid], 0)); // updates running and time at same time (i.e. acc started)

      // modify acc busy
      assert(!acc_busy[best_queue_accid]);
      acc_busy[best_queue_accid] = true;
      *out_accid = best_queue_accid;

      return false;
    } else {
      printf("SCHED: tid:%ld: choose to run on cpu\n", in_metadata->tid);
      return true;
    }
  }
}
#endif

#ifdef FCFS_RUNTIME_SKIP_OPT_BUSYWAIT
  /*
   *   if a queue is empty:
   *     enqueue into empty queue, change to running, break out of loop
   *   else:
   *     all queues have elements
   *     choose queue that is "best" to enqueue into it (only if it makes sense w.r.t running on CPU),
   *        enqueue means putting the cond_var into the queue and also stalling on it (if woken up then it is in the front of the q)
   */


  // pthread_mutex_lock(&queues_mutex);
  // pthread_mutex_unlock(&queues_mutex);
// returns if running on cpu
bool grab_accelerator_queued_runtime_opt_busywait(metadata_t* in_metadata, uint64_t* accids, size_t accids_len, size_t* out_accid) {
  uint64_t est_acc_runtime_ns = get_est_acc_runtime_ns(in_metadata);

  size_t cur_accid;
  if (is_queue_empty_busywait(accids, accids_len, &cur_accid)) {
    printf("SCHED: tid:%ld: putting in empty queue q%lu\n", in_metadata->tid, cur_accid);

// #ifdef KEEP_ASSERTS
//     // check it's not in any queue already
//     for (size_t i = 0; i < accids_len; ++i) {
//       printf("SCHED: tid:%ld: check %ld q for tid\n", in_metadata->tid, accids[i]);
//       assert(!q_found(&acc_running_q[accids[i]], in_metadata->tid));
//     }
// #endif

// #ifdef KEEP_ASSERTS
//     // put into queue
//     assert(q_empty(&acc_running_q[cur_accid]));
// #endif

    elem_t e;
    e.ns_since_epoch = 0;//get_cur_ns();
    e.est_acc_ns = est_acc_runtime_ns;// + 500; // AJG: TODO: add fudge factor (time to enqueue, do other stuff, etc), context swtich ~1us so add 1/2 of that?
    //e.metadata = in_metadata->tid;
    e.running = true;
    pthread_cond_t* thread_cond; // unused
    assert(q_enqueue_ptr(&acc_running_q[cur_accid], &e, &thread_cond));

    // modify acc busy (i.e. running on acc)
    assert(!acc_busy[cur_accid]);
    acc_busy[cur_accid] = true;
    *out_accid = cur_accid;

    return false;
  } else {
    printf("SCHED: tid:%ld: all queues have elements (maybe enqueue or skip acc)\n", in_metadata->tid);

    // choose best queue (if wanting to run on acc)
    bool run_on_acc = false;
    size_t best_queue_accid = accids[0];
    uint64_t cur_min = UINT64_MAX;
    uint64_t est_cpu_runtime_ns = get_est_cpu_runtime_ns(in_metadata);
    for (size_t i = 0; i < accids_len; ++i) {
      elem_t e;
      assert(q_peek(&acc_running_q[accids[i]], &e));
      uint64_t acc_block_for_at_least_ns = q_sum(&acc_running_q[accids[i]]);

      // AJG: this is always assuming the worst case (all tasks need to run)
      // but is also assuming that scheduling, etc takes 0 time
      int64_t ns_left_for_all_accs = (acc_block_for_at_least_ns > 0 ? acc_block_for_at_least_ns : 0);
      printf("SCHED: tid:%ld: q%lu nsleft(worstcase):%ld\n", in_metadata->tid, accids[i], ns_left_for_all_accs);

      if (est_cpu_runtime_ns > (ns_left_for_all_accs + est_acc_runtime_ns)) {
        printf("SCHED: tid:%ld: cpu expected to take longer than accs: cpur:%ld accr:%ld accr+remaining:%ld\n", in_metadata->tid, est_cpu_runtime_ns, est_acc_runtime_ns, ns_left_for_all_accs + est_acc_runtime_ns);
        run_on_acc = true;
        // find the accid queue that would be fastest
        if (est_acc_runtime_ns < cur_min) {
          cur_min = est_acc_runtime_ns;
          best_queue_accid = accids[i];
          printf("SCHED: tid:%ld: best_queue_accid:%d\n", in_metadata->tid, best_queue_accid);
        }
      }
    }

    // here run_on_acc, best_queue_accid set
    if (run_on_acc) {
      // enqueue on best_queue_accid's queue to wait (since we are guaranteed that something is before this)
      // block waiting for a change in the queue
      printf("SCHED: tid:%ld: want to run on acc, but need to wait (attempt enqueue into q%d)\n", in_metadata->tid, best_queue_accid);

// #ifdef KEEP_ASSERTS
//       // check it's not in any queue already
//       for (size_t i = 0; i < accids_len; ++i) {
//         printf("SCHED: tid:%ld: check %ld q for tid\n", in_metadata->tid, accids[i]);
//         assert(!q_found(&acc_running_q[accids[i]], in_metadata->tid));
//       }
// #endif

      if (q_full(&acc_running_q[best_queue_accid])) {
        printf("SCHED: tid:%ld: blocking, queue is full\n", in_metadata->tid);
        pthread_cond_wait(acc_running_q[best_queue_accid].full_cond, &queues_mutex);
        printf("SCHED: tid:%ld: unblocking, queue has space\n", in_metadata->tid);
      }

      // TODO: enqueue gives a ptr which you can fill (also access the cond var)
      elem_t e;
      e.est_acc_ns = est_acc_runtime_ns;// + 500; // AJG: see fudge factor comment above
      //e.metadata = in_metadata->tid;
      e.running = false;
      pthread_cond_t* thread_cond;
      assert(q_enqueue_ptr(&acc_running_q[best_queue_accid], &e, &thread_cond));
      printf("SCHED: tid:%ld: success, enqueued for waiting, blocking\n", in_metadata->tid);
      pthread_cond_wait(thread_cond, &queues_mutex);
      printf("SCHED: tid:%ld: success, acc should be free and ready to run this thread\n", in_metadata->tid);
      // i.e. this element is now at the front (need to change running to true, and set time)
// #ifdef KEEP_ASSERTS
//       assert(q_peek(&acc_running_q[best_queue_accid], &e));
//       //assert(e.metadata == in_metadata->tid);
//       assert(e.running == false);
// #endif
      //assert(q_poke_running(&acc_running_q[best_queue_accid], get_cur_ns())); // updates running and time at same time (i.e. acc started)
      assert(q_poke_running(&acc_running_q[best_queue_accid], 0)); // updates running and time at same time (i.e. acc started)

      // modify acc busy
      assert(!acc_busy[best_queue_accid]);
      acc_busy[best_queue_accid] = true;
      *out_accid = best_queue_accid;

      return false;
    } else {
      printf("SCHED: tid:%ld: choose to run on cpu\n", in_metadata->tid);
      return true;
    }
  }
}
#endif

// has the potential to block
void schedule_run_on_acc(metadata_t* metadata) {
  metadata->start_sch_ns = get_cur_ns();
  pthread_t tid = pthread_self();
  metadata->tid = tid;

#if defined(FCFS_SKIP)
  uint64_t* accids;
  uint64_t accids_len;
  get_accids(metadata->acc_type, &accids, &accids_len);
  // grabbing a cfgid, then accelerator, then opcode are combined (since a cfgid + accid + opc lifetimes are matched)
  bool acq = false;
  size_t cur_accid;
  pthread_mutex_lock(&main_mutex);
  for (size_t i = 0; i < accids_len; ++i) {
    printf("SCHED: attempting acquire of %lu\n", accids[i]);
    uint64_t accid = accids[i];
    if (!acc_busy[accid]) {
      cur_accid = accid;
      acc_busy[accid] = true;
      acq = true;
      break;
    }
  }
  pthread_mutex_unlock(&main_mutex);

  // printf("SCHED: acq:%d cur_accid:%lu\n", acq, cur_accid);

  if (acq) {
    metadata->given_accelerator = true;
    metadata->given_accid = cur_accid;
    printf("SCHED: fully acquired: accid:%ld\n", cur_accid);
  } else {
    metadata->given_accelerator = false;
    printf("SCHED: not acquired\n");
  }
  //metadata->blocked_sch_ns = 0;
#elif defined(FCFS_BLOCK_MUTEX)
  uint64_t* accids;
  uint64_t accids_len;
  get_accids(metadata->acc_type, &accids, &accids_len);

#ifdef USE_PREDICTIVE_SELECT
  pthread_mutex_lock(&queues_mutex);
  // enqueue to shorter queue (based on est.)
  size_t best_queue_accid = accids[0];
  uint64_t cur_min = UINT64_MAX;
  for (size_t i = 0; i < accids_len; ++i) {
      uint64_t acc_runtime_blocked_ns = q_sum(&acc_running_q[accids[i]]);
      uint64_t num_e = q_size(&acc_running_q[accids[i]]);

      if (acc_runtime_blocked_ns < cur_min) {
        cur_min = acc_runtime_blocked_ns;
        best_queue_accid = accids[i];
        printf("SCHED: tid:%ld: best_queue_accid:%d cur_min:%ld num_e:%ld\n", metadata->tid, best_queue_accid, cur_min, num_e);
      }
  }
  pthread_mutex_unlock(&queues_mutex);
#elif USE_MIN_SELECT
  pthread_mutex_lock(&queues_mutex);
  // enqueue to shorter queue (based on q. size)
  size_t best_queue_accid = accids[0];
  uint64_t cur_min = UINT64_MAX;
  for (size_t i = 0; i < accids_len; ++i) {
      uint64_t num_e = q_size(&acc_running_q[accids[i]]);
      if (num_e < cur_min) {
        cur_min = num_e;
        best_queue_accid = accids[i];
        printf("SCHED: tid:%ld: best_queue_accid:%d cur_min:%ld num_e:%ld\n", metadata->tid, best_queue_accid, cur_min, num_e);
      }
  }
  pthread_mutex_unlock(&queues_mutex);
#else
  size_t best_queue_accid = rand() % accids_len;
#endif

  elem_t e;
  e.ns_since_epoch = 0;
  e.est_acc_ns = get_est_acc_runtime_ns(metadata);
  e.metadata = metadata->tid;
  e.running = false;
  pthread_cond_t* thread_cond; // unused
  printf("SCHED: tid:%ld: enqueue best_queue_accid:%d\n", metadata->tid, best_queue_accid);
  pthread_mutex_lock(&queues_mutex);
  assert(q_enqueue_ptr(&acc_running_q[best_queue_accid], &e, &thread_cond));
  pthread_mutex_unlock(&queues_mutex);

#ifndef COMPLEX_WAIT
  // check if its the head to run
  pthread_mutex_lock(&queues_mutex);
  assert(q_peek(&acc_running_q[best_queue_accid], &e));
  if (metadata->tid != e.metadata) {
    printf("SCHED: tid:%ld: waiting\n", metadata->tid);
    pthread_cond_wait(thread_cond, &queues_mutex);
    printf("SCHED: tid:%ld: unblock\n", metadata->tid);
  }
  pthread_mutex_unlock(&queues_mutex);
#else
  // TODO: check if this is alright
  // check if its the head to run
#define WAIT_TIME (4000) // TODO: heuristic
  pthread_mutex_lock(&queues_mutex);
  assert(q_peek(&acc_running_q[best_queue_accid], &e));
  if (metadata->tid != e.metadata) {
    uint64_t acc_runtime_blocked_ns = q_sum(&acc_running_q[best_queue_accid]);
    if (acc_runtime_blocked_ns < WAIT_TIME) {
      printf("SCHED: tid:%ld: spinlock instead: blockfor:%lu\n", metadata->tid, acc_runtime_blocked_ns);
      pthread_mutex_unlock(&queues_mutex);
      uint64_t start_time_ns = get_cur_ns();
      uint64_t elapsed_time;
      do {
        elapsed_time = get_cur_ns() - start_time_ns;
        printf("SCHED: tid:%ld: et:%lu block:%lu\n", metadata->tid, elapsed_time, acc_runtime_blocked_ns);
      } while (elapsed_time < acc_runtime_blocked_ns);
      pthread_mutex_lock(&queues_mutex);

      assert(q_peek(&acc_running_q[best_queue_accid], &e));
      printf("SCHED: tid:%ld: check qid:%ld qtid:%ld\n", metadata->tid, best_queue_accid, e.metadata);
      if (metadata->tid != e.metadata) {
        printf("SCHED: tid:%ld: waiting (after spin)\n", metadata->tid);
        pthread_cond_wait(thread_cond, &queues_mutex);
        printf("SCHED: tid:%ld: unblock (after spin)\n", metadata->tid);
      }
      printf("SCHED: tid:%ld: passed\n", metadata->tid);
    } else {
      printf("SCHED: tid:%ld: waiting\n", metadata->tid);
      pthread_cond_wait(thread_cond, &queues_mutex);
      printf("SCHED: tid:%ld: unblock\n", metadata->tid);
    }
  }
  pthread_mutex_unlock(&queues_mutex);
#endif

  // TODO: loop blocking implementation
  // do {
  //   lock();
  //   assert(q_peek(&acc_running_q[best_queue_accid], &e));
  //   printf("SCHED: tid:%ld: check qid:%ld qmid:%ld emid:%ld\n", metadata->tid, best_queue_accid, metadata->mid, e.metadata);
  //   unlock();
  // } while (metadata->mid != e.metadata);

  metadata->given_accelerator = true;
  metadata->given_accid = best_queue_accid;

#elif defined(FCFS_BLOCK_SPINLOCK)
  uint64_t* accids;
  uint64_t accids_len;
  get_accids(metadata->acc_type, &accids, &accids_len);

#ifdef USE_RANDOM_SELECT
  size_t best_queue_accid = rand() % accids_len;
#elif USE_MIN_SELECT
  pthread_spin_lock(&queue_balance_spinlock); // still needed to ensure you load balance properly
  // enqueue to shorter queue (based on q. size)
  size_t best_queue_accid = accids[0];
  uint64_t cur_min = UINT64_MAX;
  for (size_t i = 0; i < accids_len; ++i) {
      pthread_spin_lock(&queues_spinlock);
      uint64_t num_e = qagain_size(&acc_running_qagain[accids[i]]);
      pthread_spin_unlock(&queues_spinlock);
      if (num_e < cur_min) {
        cur_min = num_e;
        best_queue_accid = accids[i];
        printf("SCHED: tid:%ld: best_queue_accid:%d cur_min:%ld num_e:%ld\n", metadata->tid, best_queue_accid, cur_min, num_e);
      }
  }
  pthread_spin_unlock(&queue_balance_spinlock);
#else
  size_t best_queue_accid = 0; // TODO
#endif

  elem_t e;
  e.est_acc_ns = get_est_acc_runtime_ns(metadata);
  e.metadata = metadata->tid;
  printf("SCHED: tid:%ld: attempting enqueue best_queue_accid:%d\n", metadata->tid, best_queue_accid);
  pthread_spin_lock(&queues_spinlock);
  bool rc = qagain_enqueue(&acc_running_qagain[best_queue_accid], &e);
  pthread_spin_unlock(&queues_spinlock);
  if (rc == false) {
    metadata->given_accelerator = false;
    printf("SCHED: tid:%ld not acquired (queue was full)\n", metadata->tid);
  } else {
    printf("SCHED: tid:%ld: enqueued to accid:%d\n", metadata->tid, best_queue_accid);

    do {
      size_t skew = 25 + (rand() % 50);
      for (int i = 0; i < skew; i++) {}
      pthread_spin_lock(&queues_spinlock);
      bool rc = qagain_peek(&acc_running_qagain[best_queue_accid], &e);
      pthread_spin_unlock(&queues_spinlock);
    } while (!rc || (e.metadata != metadata->tid));

    printf("SCHED: found tid:%ld e:%ld\n", metadata->tid, e.metadata);

    metadata->given_accelerator = true;
    metadata->given_accid = best_queue_accid;
  }
// #elif defined(FCFS_BLOCK_LOCKFREE)
//   uint64_t* accids;
//   uint64_t accids_len;
//   get_accids(metadata->acc_type, &accids, &accids_len);
//
// #ifdef USE_RANDOM_SELECT
//   size_t best_queue_accid = rand() % accids_len;
// #elif USE_MIN_SELECT
//   pthread_spin_lock(&queues_spinlock); // still needed to ensure you load balance properly
//   // enqueue to shorter queue (based on q. size)
//   size_t best_queue_accid = accids[0];
//   uint64_t cur_min = UINT64_MAX;
//   for (size_t i = 0; i < accids_len; ++i) {
//       uint64_t num_e = rqueue_current_size(acc_running_rq[accids[i]]);
//       if (num_e < cur_min) {
//         cur_min = num_e;
//         best_queue_accid = accids[i];
//         printf("SCHED: tid:%ld: best_queue_accid:%d cur_min:%ld num_e:%ld\n", metadata->tid, best_queue_accid, cur_min, num_e);
//       }
//   }
//   pthread_spin_unlock(&queues_spinlock);
// #else
//   size_t best_queue_accid = 0; // TODO
// #endif
//
//   rqueue_elem_t* e = malloc(sizeof(rqueue_elem_t));
//   e->metadata = metadata->tid;
//   e->est_acc_ns = get_est_acc_runtime_ns(metadata);
//   printf("SCHED: tid:%ld attempting e:%lu\n", metadata->tid, e);
//   int rc = rqueue_write(acc_running_rq[best_queue_accid], e);
//   if (rc == -2) {
//     free(e);
//     metadata->given_accelerator = false;
//     printf("SCHED: tid:%ld not acquired (queue was full)\n", metadata->tid);
//   } else {
//     assert(rc == 0);
//
//     printf("SCHED: tid:%ld: enqueued to accid:%d w:%d r:%d\n", metadata->tid, best_queue_accid, rqueue_write_count(acc_running_rq[best_queue_accid]), rqueue_read_count(acc_running_rq[best_queue_accid]));
//
//     // needs to be atomic since read + free could f this up
//     //   - is there a case where it's getting peeked and this is free'ed before reading the metadata (maybe)
//     while (rqueue_peek_check(acc_running_rq[best_queue_accid], metadata->tid) == 0) {
//       size_t skew = 25 + (rand() % 50);
//       for (int i = 0; i < skew; i++) {}
//     }
//
//     printf("SCHED: found tid:%ld\n", metadata->tid);
//
//     metadata->given_accelerator = true;
//     metadata->given_accid = best_queue_accid;
//   }
#elif defined(UNLIMITED)
  metadata->given_accelerator = true;
  //metadata->blocked_sch_ns = 0;
#elif defined(FCFS_RUNTIME_SKIP)
  uint64_t* accids;
  uint64_t accids_len;
  get_accids(metadata->acc_type, &accids, &accids_len);
  // grabbing a cfgid, then accelerator, then opcode are combined (since a cfgid + accid + opc lifetimes are matched)
  bool acq = false;
  size_t cur_accid;
  bool previously_enqueued = false;
  bool run_on_cpu = false;
  int32_t cfgid;
  uint64_t start = get_cur_ns();
  pthread_mutex_lock(&queues_mutex);
  printf("SCHED: tid:%lu grabbed lock (m:%p)\n", tid, metadata);
  // in this case acq means "break out of loop" not that it acquired an accelerator
  acq = grab_accelerator_queued_runtime(metadata, &queues_cond, &previously_enqueued, &run_on_cpu, accids, accids_len, &cfgid, &cur_accid); // can potentially signal
  while (!acq) {
    printf("SCHED: do wait: tid:%lu (m:%p)\n", tid, metadata);
    //pthread_cond_signal(&queues_cond);
    //pthread_cond_wait_wrapper("rt", &queues_cond, &queues_mutex);
    pthread_cond_wait(&queues_cond, &queues_mutex);
    printf("SCHED: wait over: tid:%lu (m:%p)\n", tid, metadata);
    acq = grab_accelerator_queued_runtime(metadata, &queues_cond, &previously_enqueued, &run_on_cpu, accids, accids_len, &cfgid, &cur_accid); // can potentially signal
  }
  pthread_mutex_unlock(&queues_mutex);
  printf("SCHED: tid:%lu unlock (m:%p)\n", tid, metadata);
  uint64_t end = get_cur_ns();

  printf("SCHED: tid:%lu was acquired?: runcpu:%d accid:%ld\n", tid, run_on_cpu, cur_accid);
  //metadata->blocked_sch_ns = end - start;
  metadata->given_accelerator = !run_on_cpu;
  metadata->given_cfgid = cfgid;
  metadata->given_accid = cur_accid;
#elif defined(FCFS_RUNTIME_SKIP_OPT)
  uint64_t* accids;
  uint64_t accids_len;
  get_accids(metadata->acc_type, &accids, &accids_len);
  // grabbing a cfgid, then accelerator, then opcode are combined (since a cfgid + accid + opc lifetimes are matched)
  size_t cur_accid;
  pthread_mutex_lock(&queues_mutex);
  printf("SCHED: tid:%lu grabbed lock (m:%p)\n", tid, metadata);
  metadata->given_accelerator = !grab_accelerator_queued_runtime_opt(metadata, accids, accids_len, &cur_accid); // can potentially signal
  pthread_mutex_unlock(&queues_mutex);
  printf("SCHED: tid:%lu unlock (m:%p)\n", tid, metadata);

  printf("SCHED: tid:%lu was acquired?: runcpu:%d accid:%ld\n", tid, !metadata->given_accelerator, cur_accid);
  //metadata->blocked_sch_ns = end - start;
  //metadata->given_cfgid = 0;
  metadata->given_accid = cur_accid;
#elif defined(FCFS_RUNTIME_SKIP_OPT_BUSYWAIT)
  uint64_t* accids;
  uint64_t accids_len;
  get_accids(metadata->acc_type, &accids, &accids_len);
  // grabbing a cfgid, then accelerator, then opcode are combined (since a cfgid + accid + opc lifetimes are matched)
  size_t cur_accid;
  bool acq = false;
  SpinlockLock(&globalspinlock);
  acq = grab_accelerator_queued_runtime_opt_busywait(metadata, &queues_cond, &previously_enqueued, &run_on_cpu, accids, accids_len, &cfgid, &cur_accid); // can potentially signal
  while (!acq) {
    SpinlockUnlock(&globalspinlock);
    acq = grab_accelerator_queued_runtime_opt_busywait(metadata, &queues_cond, &previously_enqueued, &run_on_cpu, accids, accids_len, &cfgid, &cur_accid); // can potentially signal
  }
  pthread_mutex_unlock(&queues_mutex);

  SpinlockLock(&globalspinlock);
  metadata->given_accelerator = !grab_accelerator_queued_runtime_opt_busywait(metadata, accids, accids_len, &cur_accid); // can potentially signal
  SpinlockUnlock(&globalspinlock);
  printf("SCHED: tid:%lu unlock (m:%p)\n", tid, metadata);

  printf("SCHED: tid:%lu was acquired?: runcpu:%d accid:%ld\n", tid, !metadata->given_accelerator, cur_accid);
  //metadata->blocked_sch_ns = end - start;
  //metadata->given_cfgid = 0;
  metadata->given_accid = cur_accid;
#else
  metadata->given_accelerator = false;
  //metadata->blocked_sch_ns = 0;
#endif
}

static void delay(void) {
  // inject latency to see any issues
  int r = rand() % 10000000000;
  printf("SCHED: delay for %d\n", r);
  while (r > 0) {
    --r;
  }
}

// TODO: only acquire and release if another CPU wants it... i.e. pay penalty only once
void schedule_release_and_update(metadata_t* metadata) {
  printf("SCHED: release: tid:%lu meta:%p given:%d accid:%ld\n", metadata->tid, metadata, metadata->given_accelerator, metadata->given_accid);
  size_t q_max_size = 0;
  if (metadata->given_accelerator) {
    printf("SCHED: doing release tid:%lu cfgid:%ld accid:%ld\n", metadata->tid, metadata->given_cfgid, metadata->given_accid);
#if defined(FCFS_SKIP)
    pthread_mutex_lock(&main_mutex);
    acc_busy[metadata->given_accid] = false;
    pthread_mutex_unlock(&main_mutex);
#elif defined(FCFS_BLOCK_MUTEX)
    printf("SCHED: release dequeue: tid:%lu meta:%p given:%d accid:%ld\n", metadata->tid, metadata, metadata->given_accelerator, metadata->given_accid);
    pthread_mutex_lock(&queues_mutex);
    assert(q_dequeue(&acc_running_q[metadata->given_accid]));
    pthread_mutex_unlock(&queues_mutex);

    pthread_mutex_lock(&queues_mutex);
    // the next element in the current queue should grab the acc and start (use it's cond var to start it)
    if (!q_empty(&acc_running_q[metadata->given_accid])) {
      elem_t e;
      assert(q_peek(&acc_running_q[metadata->given_accid], &e));
      // uint64_t cur_sz = q_size(&acc_running_q[metadata->given_accid]);
      // printf("SCHED: tid:%ld: signal next thread to start: %lu (cursz: %lu)\n", metadata->tid, e.metadata, cur_sz);
      pthread_cond_signal(e.thread_cond);
    }
    pthread_mutex_unlock(&queues_mutex);

    pthread_mutex_lock(&queues_mutex);
    q_max_size = q_maxsize(&acc_running_q[metadata->given_accid]);
    pthread_mutex_unlock(&queues_mutex);
#elif defined(FCFS_BLOCK_SPINLOCK)
    printf("SCHED: release dequeue: tid:%lu meta:%p given:%d accid:%ld\n", metadata->tid, metadata, metadata->given_accelerator, metadata->given_accid);
    pthread_spin_lock(&queues_spinlock);
    assert(qagain_dequeue(&acc_running_qagain[metadata->given_accid]));
    pthread_spin_unlock(&queues_spinlock);
    //acc_busy[metadata->given_accid] = false;

    pthread_spin_lock(&queues_spinlock);
    q_max_size = qagain_maxsize(&acc_running_qagain[metadata->given_accid]);
    pthread_spin_unlock(&queues_spinlock);
// #elif defined(FCFS_BLOCK_LOCKFREE)
//     printf("SCHED: release dequeue: tid:%lu meta:%p given:%d accid:%ld\n", metadata->tid, metadata, metadata->given_accelerator, metadata->given_accid);
//     //q_max_size = rqueue_size(acc_running_rq[metadata->given_accid]); // TODO: not max size for this but just size
//
//     while (rqueue_pop(acc_running_rq[metadata->given_accid]) == 0) {
//       printf("SCHED: waiting to pop: tid:%lu\n", metadata->tid);
//     }
//
//     // rqueue_elem_t* e = NULL;
//     // do {
//     //   size_t skew = 25 + (rand() % 50);
//     //   for (int i = 0; i < skew; i++) {}
//     //   e = rqueue_read(acc_running_rq[metadata->given_accid]);
//     //   printf("SCHED: tid:%lu got:%lu cursz:%lu\n", metadata->tid, e, rqueue_current_size(acc_running_rq[metadata->given_accid]));
//     // } while (e == NULL);
//     // free(e);
//
//     printf("SCHED: dequeued: tid:%lu\n", metadata->tid);
//     //acc_busy[metadata->given_accid] = false;
#elif defined(FCFS_RUNTIME_SKIP)
    pthread_mutex_lock(&queues_mutex);
    printf("SCHED: release dequeue: tid:%lu meta:%p given:%d accid:%ld\n", metadata->tid, metadata, metadata->given_accelerator, metadata->given_accid);
#ifdef KEEP_ASSERTS
    elem_t e;
    assert(q_peek(&acc_running_q[metadata->given_accid], &e));
    assert(e.metadata == metadata->tid);
    assert(e.running == true);
#endif
    assert(q_dequeue(&acc_running_q[metadata->given_accid]));
    printf("SCHED: tid:%ld: check curq%ld for tid\n", metadata->tid, metadata->given_accid);
#ifdef KEEP_ASSERTS
    assert(!q_found(&acc_running_q[metadata->given_accid], metadata->tid));
    uint64_t* accids;
    uint64_t accids_len;
    get_accids(metadata->acc_type, &accids, &accids_len);
    // check it's not in any queue already
    for (size_t i = 0; i < accids_len; ++i) {
      printf("SCHED: tid:%ld: release check %ld q for tid\n", metadata->tid, accids[i]);
      assert(!q_found(&acc_running_q[accids[i]], metadata->tid));
    }
#endif
    acc_busy[metadata->given_accid] = false;
    pthread_cond_broadcast(&queues_cond); // something happened with queues+acc, signal
    pthread_mutex_unlock(&queues_mutex);
    printf("SCHED: tid:%lu unlock\n", metadata->tid);

#elif defined(FCFS_RUNTIME_SKIP_OPT)
    pthread_mutex_lock(&queues_mutex);
    printf("SCHED: release dequeue: tid:%lu meta:%p given:%d accid:%ld\n", metadata->tid, metadata, metadata->given_accelerator, metadata->given_accid);
// #ifdef KEEP_ASSERTS
//     elem_t e;
//     assert(q_peek(&acc_running_q[metadata->given_accid], &e));
//     //assert(e.metadata == metadata->tid);
//     assert(e.running == true);
// #endif
    acc_busy[metadata->given_accid] = false;
    assert(q_dequeue(&acc_running_q[metadata->given_accid]));
    printf("SCHED: tid:%ld: check curq%ld for tid\n", metadata->tid, metadata->given_accid);
// #ifdef KEEP_ASSERTS
//     //assert(!q_found(&acc_running_q[metadata->given_accid], metadata->tid));
//     uint64_t* accids;
//     uint64_t accids_len;
//     get_accids(metadata->acc_type, &accids, &accids_len);
//     // check it's not in any queue already
//     for (size_t i = 0; i < accids_len; ++i) {
//       printf("SCHED: tid:%ld: release check %ld q for tid\n", metadata->tid, accids[i]);
//       //assert(!q_found(&acc_running_q[accids[i]], metadata->tid));
//     }
// #endif

    // the next element in the current queue should grab the acc and start (use it's cond var to start it)
    if (!q_empty(&acc_running_q[metadata->given_accid])) {
      elem_t e;
      assert(q_peek(&acc_running_q[metadata->given_accid], &e));
      printf("SCHED: tid:%ld: signal next thread to start\n", metadata->tid);
      pthread_cond_signal(e.thread_cond);
    }

    // done after signaling for next acc to start because full will take a while anyways to this should be last
    // want to immediately enqueue work on acc over filling q
    pthread_cond_signal(acc_running_q[metadata->given_accid].full_cond); // signal to any threads blocked on full that it isn't anymore

    pthread_mutex_unlock(&queues_mutex);
    printf("SCHED: tid:%lu unlock\n", metadata->tid);
#endif
  }

#if (defined(FCFS_RUNTIME_SKIP) || defined(FCFS_RUNTIME_SKIP_OPT) || defined(FCFS_BLOCK_SPINLOCK) || defined(FCFS_BLOCK_LOCKFREE) || defined(FCFS_BLOCK_MUTEX)) && defined(USE_FEEDBACK)
  // updating cpu time
  update_cpu_proto_runtime_tput(metadata->mid,
             metadata->size,
             metadata->given_accelerator ? (metadata->runtime_ns * ACC_SPEEDUP) : metadata->runtime_ns);
#endif

  uint64_t runtime_sch_ns = get_cur_ns() - metadata->start_sch_ns;
  printf("SCHED: release: ga:%d acc_type:%d sched_r_ns:%luns provided_r_ns:%luns blocked_sch_ns:%lu q_max_size:%lu\n",
         metadata->given_accelerator,
         metadata->acc_type,
         runtime_sch_ns,
         metadata->runtime_ns, 0, q_max_size);
         /*metadata->blocked_sch_ns);*/
  // need to know if grabbed accel, time blacked, time to run w/ accel (plus misc. setup), time from sched.
  //
  // if was given accel
  // <---------------------------------------> sched time (runtime_sch_ns)
  //      <-----------------> time for acc run (runtime_ns)
  // <---->  time blocked waiting for acc (blocked_sch_ns)
  //
  // else if not
  // <----------------------------------------> time for cpu run (runtime_ns)
  fprintf(fp, "%d,%d,%lu,%lu,%lu\n",
          metadata->given_accelerator,
          metadata->given_accid,
          runtime_sch_ns,
          metadata->runtime_ns,
          q_max_size
          );//, 0);
  // // TODO: use this for faster speed
  // fprintf(fp, "%d\n",
  //         metadata->given_accelerator);
  //         /*metadata->blocked_sch_ns);*/
  //fflush(fp);
}

void PassSerInfoToScheduler(volatile uint8_t** string_pointer_region, volatile uint8_t* string_data_region) {
}

void GetSerInfoFromScheduler(volatile uint8_t*** string_pointer_region_out, volatile uint8_t** string_data_region_out) {
}

void PassDeserInfoToScheduler(volatile uint8_t* fixed_alloc_region, volatile uint8_t* array_alloc_region) {
}

void GetDeserInfoFromScheduler(volatile uint8_t** fixed_alloc_region_out, volatile uint8_t** array_alloc_region_out) {
}

void CompressMemSetup(void) {
}

void GiveCompressMemTemps(uint8_t accid, volatile uint8_t** litbuf_out, size_t* litbuf_sz_out, volatile uint8_t** seqbuf_out, size_t* seqbuf_sz_out) {
}

void DecompressMemSetup(void) {
}

void GiveDecompressMemTemps(uint8_t accid, volatile uint8_t** workspace_out, size_t* workspace_sz_out) {
}
