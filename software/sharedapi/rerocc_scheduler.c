#define _GNU_SOURCE
#include <assert.h>
#include <pthread.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/sysinfo.h>
#include <sched.h>

#include "rerocc_scheduler.h"
#include "helpers.h"
#include "queue.h"

//#define USE_FEEDBACK (1)
//#define printf(...) (0)
#ifndef KEEP_ASSERTS
#define assert(x) (x)
#endif

// ----- Section for Runtime Estimation Models ----- //

#define MAX_ENC_DEC_SAMPLES (10)

// Make the encryption model variables global variables
size_t enc_sizes_sampled[MAX_ENC_DEC_SAMPLES + 1] = {0, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192};
size_t dec_sizes_sampled[MAX_ENC_DEC_SAMPLES + 1] = {0, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192};
// this is in bits (all are rounded to ints)
size_t enc_b_per_ns[MAX_ENC_DEC_SAMPLES + 1] = {0, 2, 3, 6, 9, 14, 19, 23, 26, 28, 29};
size_t dec_b_per_ns[MAX_ENC_DEC_SAMPLES + 1] = {0, 1, 3, 5, 9, 14, 20, 25, 28, 30, 31};
#if defined(USE_FEEDBACK)
// Each linear model should have xtx, xty, and ab as global variables
// For example, double xtx[2][4] = {
//   {1,2,3,4},
//   {5,6,7,8}
// };
// where xtx[0] is for accelerator type 0 and so on.
// xtx[0]=sum of x^2, xtx[1]=[2]=sum of x, xtx[3]=sum of 1
double xtx[4][4] = {
  {1234, 12, 12, 1},
  {1234, 12, 12, 1},
  {1234, 12, 12, 1},
  {1234, 12, 12, 1}
};
// xty[0]=sum of xy, xty[1]=sum of y
double xty[4][2] = {
  {12345, 345},
  {12345, 345},
  {12345, 345},
  {12345, 345}
};
#endif
// ab is the model paramter, such that y=ax+b.
// ab[1] is a and ab[0] is b (Math convention)
// For compression, there can be more than one model...
double ab[5][2] = {
  {1234, 1234},
  {1234, 1234},
  {1234, 1234},
  {1234, 1234},
  {5.7044,-0.065}, //Decomp, ratio<0.67. x=ratio, y=decomp speed. R^2=0.64.

};

// ----------------------------------------------- //


size_t MAX_PROTOBUF_SER_IDS;
uint64_t protobuf_ser_accids[1000];

#define MAX_ACC_ID (1000) // max of the above ids
queue_t acc_running_q[MAX_ACC_ID]; // indexed by accid

// HACK: fake accelerator busy or not
bool acc_busy[MAX_ACC_ID];

// fill arr + len with arr/len of the accelerator wanted
void get_accids(acc_type_t acc_type, uint64_t** arr, uint64_t* len) {
  *arr = protobuf_ser_accids;
  *len = MAX_PROTOBUF_SER_IDS;
}

pthread_mutex_t main_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t main_cond = PTHREAD_COND_INITIALIZER;
pthread_mutex_t queues_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t queues_cond = PTHREAD_COND_INITIALIZER;

FILE *fp;

#ifndef MAX_ACCS
#define MAX_ACCS (2)
#endif

// scheduler can be shared between threads of a same process (client/server in 1 binary running localhost)
// scheduler can be shared between threads of different process (client/server in 2 binaries running as localhost)
//   not an option in this case for us
// otherwise scheduler is on two separate machines w/ different accelerators (no sharing necessary)
//
// thus we can default to just synch. between threads of the same process
void init_scheduler(void) {
  //setbuf(stdout, NULL);
  // ok to clear twice (since we expect server will be setup before client)
  for (size_t i = 0; i < MAX_ACC_ID; ++i) {
    q_init(&acc_running_q[i]);
    acc_busy[i] = false;
  }

  MAX_PROTOBUF_SER_IDS = MAX_ACCS;
  for (size_t i = 0; i < MAX_ACCS; ++i) {
    protobuf_ser_accids[i] = i;
  }

  fp = fopen("sched.txt", "w");
  if (fp == NULL) {
    printf("SCHED: unable to open file\n");
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

typedef struct proto_rt_entry_t {
  void* descriptor_ptr;
  size_t ns_per_B; // this is in bytes
} proto_rt_entry_t;

#define MAX_ENTRIES 1000
typedef struct proto_runtime_data_t {
  proto_rt_entry_t entries[MAX_ENTRIES];
  size_t num_entries;
} proto_runtime_data_t;

proto_runtime_data_t ser_data;

static size_t cpu_proto_runtime_ns(void* descriptor_ptr, size_t size) {
  for (size_t i = 0; i < ser_data.num_entries; ++i) {
    proto_rt_entry_t entry = ser_data.entries[i];
    if (entry.descriptor_ptr == descriptor_ptr) {
      printf("CPU Prediction sz:%lu * ns_p_B:%lu = ns:%lu\n", size, entry.ns_per_B, size * entry.ns_per_B);
      return size * entry.ns_per_B; // this is reverse ns_per_B
    }
  }

  assert(false && "SHOULDN'T REACH HERE");
  return 0;
}

void update_ser(const void* descriptor_ptr, uint32_t ns_per_B){
  for (size_t i = 0; i < ser_data.num_entries; ++i) {
    proto_rt_entry_t* entry = &ser_data.entries[i];
    // override prior entry w/ avg of the two
    if (entry->descriptor_ptr == descriptor_ptr) {
      entry->ns_per_B = (entry->ns_per_B + ns_per_B) / 2;
      entry->ns_per_B = entry->ns_per_B == 0 ? 1 : entry->ns_per_B;
      printf("Updating prediction %p with %ldns/B (input: %ldns/B)\n", descriptor_ptr, entry->ns_per_B, ns_per_B);
      return;
    }
  }

  assert(false && "SHOULDN'T REACH HERE");
}

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
      // fill the queue with least amt of work i.e. entries
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

uint64_t get_est_acc_runtime_ns(metadata_t* metadata) {
  return cpu_proto_runtime_ns((void*)metadata->descriptor_ptr, metadata->size) / ACC_SPEEDUP;
}

uint64_t get_est_cpu_runtime_ns(metadata_t* metadata) {
  return cpu_proto_runtime_ns((void*)metadata->descriptor_ptr, metadata->size);
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
    e.ns_since_epoch = get_cur_ns();
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
      uint64_t running_or_nextup_start_ns = e.ns_since_epoch; // when enqueued and is running this time is valid (i.e. time from when acc was grabbed/started work)
      uint64_t time_since_first_acc_started_ns = get_cur_ns() - running_or_nextup_start_ns;

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
      assert(q_poke_running(&acc_running_q[best_queue_accid], get_cur_ns())); // updates running and time at same time (i.e. acc started)

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

uint64_t get_cur_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_BOOTTIME, &ts);
  return (1e9 * ts.tv_sec) + ts.tv_nsec;
}

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
  if (metadata->given_accelerator) {
    printf("SCHED: doing release tid:%lu cfgid:%ld accid:%ld\n", metadata->tid, metadata->given_cfgid, metadata->given_accid);
#if defined(FCFS_SKIP)
    pthread_mutex_lock(&main_mutex);
    acc_busy[metadata->given_accid] = false;
    pthread_mutex_unlock(&main_mutex);
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

#if (defined(FCFS_RUNTIME_SKIP) || defined(FCFS_RUNTIME_SKIP_OPT)) && defined(USE_FEEDBACK)
  pthread_mutex_lock(&queues_mutex);
  // updating cpu time
  update_ser(metadata->descriptor_ptr,
             metadata->given_accelerator ?
             (metadata->runtime_ns * ACC_SPEEDUP) / metadata->size :
             metadata->runtime_ns / metadata->size);
  pthread_mutex_unlock(&queues_mutex);
#endif

  uint64_t runtime_sch_ns = get_cur_ns() - metadata->start_sch_ns;
  printf("SCHED: release: ga:%d acc_type:%d sched_r_ns:%luns provided_r_ns:%luns blocked_sch_ns:%lu\n",
         metadata->given_accelerator,
         metadata->acc_type,
         runtime_sch_ns,
         metadata->runtime_ns, 0);
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
          metadata->runtime_ns, 0);
          /*metadata->blocked_sch_ns);*/
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

void SetTputSer(const void* descriptor_ptr, uint32_t ns_per_B) {
  proto_runtime_data_t* data = &ser_data;
  for (size_t i = 0; i < data->num_entries; ++i) {
    proto_rt_entry_t* entry = &data->entries[i];
    // override prior entry w/ avg of the two
    if (entry->descriptor_ptr == descriptor_ptr) {
      entry->ns_per_B = (entry->ns_per_B + ns_per_B) / 2;
      entry->ns_per_B = entry->ns_per_B == 0 ? 1 : entry->ns_per_B;
      fprintf(stderr, "Overrode %p with %ldns/B (input: %ldns/B)\n", descriptor_ptr, entry->ns_per_B, ns_per_B);
      return;
    }
  }

  assert(data->num_entries < MAX_ENTRIES);
  fprintf(stderr, "Added throughput %ldns/B (if 0->1) for %p\n", ns_per_B, descriptor_ptr);
  data->entries[data->num_entries].descriptor_ptr = (void*)descriptor_ptr;
  ns_per_B = (ns_per_B == 0) ? 1 : ns_per_B;
  data->entries[data->num_entries].ns_per_B = ns_per_B;
  data->num_entries += 1;
}
