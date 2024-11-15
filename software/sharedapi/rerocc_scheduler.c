#if !defined(__x86_64__)

#define _GNU_SOURCE
#include <assert.h>
#include <pthread.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/sysinfo.h>
#include <sched.h>

#include "rerocc_scheduler.h"
#include "rerocc.h"
#include "helpers.h"
#include "queue.h"

#define MAX_PROTOBUF_SER_IDS (2)
uint8_t protobuf_ser_accids[MAX_PROTOBUF_SER_IDS] = {6, 7};

#define MAX_PROTOBUF_DESER_IDS (2)
uint8_t protobuf_deser_accids[MAX_PROTOBUF_DESER_IDS] = {4, 5};

#define MAX_COMPRESS_IDS (1)
uint8_t compress_accids[MAX_COMPRESS_IDS] = {8};

#define MAX_DECOMPRESS_IDS (1)
uint8_t decompress_accids[MAX_DECOMPRESS_IDS] = {9};

#define MAX_ENCRYPT_DECRYPT_IDS (2)
uint8_t encrypt_decrypt_accids[MAX_ENCRYPT_DECRYPT_IDS] = {0, 1};

#define MAX_ACC_ID ((9) + 1) // max of the above ids
queue_t acc_running_q[MAX_ACC_ID]; // indexed by accid

// fill arr + len with arr/len of the accelerator wanted
void get_accids(acc_type_t acc_type, uint8_t** arr, uint8_t* len) {
  switch (acc_type) {
    case PROTOBUF_SER:
      *arr = protobuf_ser_accids;
      *len = MAX_PROTOBUF_SER_IDS;
      break;
    case PROTOBUF_DESER:
      *arr = protobuf_deser_accids;
      *len = MAX_PROTOBUF_DESER_IDS;
      break;
    case COMPRESS:
      *arr = compress_accids;
      *len = MAX_COMPRESS_IDS;
      break;
    case DECOMPRESS:
      *arr = decompress_accids;
      *len = MAX_DECOMPRESS_IDS;
      break;
    case ENCRYPT:
    case DECRYPT:
      *arr = encrypt_decrypt_accids;
      *len = MAX_ENCRYPT_DECRYPT_IDS;
      break;
    default:
      printf("SCHED: unsupported acc_type:%ld\n", acc_type);
  }
}

pthread_mutex_t main_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t main_cond = PTHREAD_COND_INITIALIZER;
pthread_mutex_t queues_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t queues_cond = PTHREAD_COND_INITIALIZER;

// scheduler can be shared between threads of a same process (client/server in 1 binary running localhost)
// scheduler can be shared between threads of different process (client/server in 2 binaries running as localhost)
//   not an option in this case for us
// otherwise scheduler is on two separate machines w/ different accelerators (no sharing necessary)
//
// thus we can default to just synch. between threads of the same process
void init_scheduler(void) {
  // ok to clear twice (since we expect server will be setup before client)
  for (size_t i = 0; i < MAX_ACC_ID; ++i) {
    q_init(&acc_running_q[i]);
  }

  int num_cores = get_nprocs();
  printf("SCHED: init scheduler for %d cores\n", num_cores);
}

typedef struct proto_rt_entry_t {
  void* desc_ptr;
  size_t throughput_b_per_ns; // this is in bytes
} proto_rt_entry_t;

typedef struct proto_runtime_data_t {
  proto_rt_entry_t* entries;
  size_t num_entries;
} proto_runtime_data_t;

proto_runtime_data_t ser_data;
proto_runtime_data_t deser_data;

static size_t proto_runtime_ns(bool ser, void* desc_ptr, size_t size) {
  proto_runtime_data_t* data = ser ? &ser_data : &deser_data;
  for (size_t i = 0; i < data->num_entries; ++i) {
    proto_rt_entry_t entry = data->entries[i];
    if (entry.desc_ptr == desc_ptr) {
      return size / entry.throughput_b_per_ns;
    }
  }
  printf("SCHED: No proto prediction\n");
  return 0;
}

// TODO: collected for AES128... need on firesim
static size_t encrypt_runtime_ns(bool enc, size_t size) {
  assert(size != 0);
  // collect from baremetal testing w/ no contention
#define MAX_ENC_DEC_SAMPLES (10)
  size_t sizes_sampled[MAX_ENC_DEC_SAMPLES + 1] = {0, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192};

  // this is in bits (all are rounded to ints)
  size_t enc_b_per_ns[MAX_ENC_DEC_SAMPLES + 1] = {0, 2, 3, 6, 9, 14, 19, 23, 26, 28, 29};
  size_t dec_b_per_ns[MAX_ENC_DEC_SAMPLES + 1] = {0, 1, 3, 5, 9, 14, 20, 25, 28, 30, 31};

  size_t max_idx = MAX_ENC_DEC_SAMPLES + 2;
  for (size_t i = 0; i < MAX_ENC_DEC_SAMPLES + 1; ++i) {
    printf("SCHED: sz:%ld v.s. samplesz:%ld\n", size, sizes_sampled[i]);
    if (size < sizes_sampled[i]) {
      max_idx = i;
      break;
    }
  }

  printf("SCHED: max_idx:%ld\n", max_idx);

  size_t* b_per_ns = (enc ? enc_b_per_ns : dec_b_per_ns);

  size_t size_b = 8 * size;
  if (max_idx == MAX_ENC_DEC_SAMPLES + 2) {
    printf("SCHED: enc:%d do max est: maxtp:%ld\n", enc, b_per_ns[MAX_ENC_DEC_SAMPLES]);
    return size_b / b_per_ns[MAX_ENC_DEC_SAMPLES];
  } else {
    // do interpolation to get close-ish throughput
    size_t min_idx = max_idx - 1;
    printf("SCHED: enc:%d interpolate: max:%ld min:%ld\n", enc, max_idx, min_idx);
    size_t max_tput = b_per_ns[max_idx];
    size_t min_tput = b_per_ns[min_idx];
    printf("SCHED: enc:%d interpolate: maxtp:%ld mintp:%ld\n", enc, max_tput, min_tput);
    return (size_b * (sizes_sampled[max_idx] - sizes_sampled[min_idx])) / ((size - sizes_sampled[min_idx]) * (max_tput - min_tput));
  }
}

static bool is_queue_empty(uint8_t* accids, size_t accids_len, size_t* empty_queue_id) {
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

static bool is_ready_to_acquire(uint8_t* accids, size_t accids_len, size_t* ready_queue_id, metadata_t* in_metadata) {
  elem_t peek_metadata;
  for (size_t i = 0; i < accids_len; ++i) {
    assert(q_peek(&acc_running_q[accids[i]], &peek_metadata));
    printf("SCHED: peeked queueid:%lu peeked:%lx in:%lx masked:%lx\n", accids[i], peek_metadata.metadata, (uint64_t)in_metadata, (peek_metadata.metadata & (~METADATA_MASK)));
    if ((peek_metadata.metadata & (~METADATA_MASK)) == (uint64_t)in_metadata) {
      printf("SCHED: metadata match\n");
      assert((peek_metadata.metadata & METADATA_MASK) == 0); // should be not running
      *ready_queue_id = accids[i];
      return true;
    }
  }
  return false;
}

// queue elem = metadata_ptr (assumed to be aligned to 16), where lowest bit 0 or 1 is running or not
// if queue = empty -> then nothing running
// if queue has elem -> that elem is either running or is up next to run
// if queue has multiple elems -> 1 elem is same as above, next ones are waiting
bool grab_accelerator_queued(metadata_t* in_metadata, pthread_cond_t* queues_cond, bool* previously_enqueued, uint8_t* accids, size_t accids_len, int32_t* out_cfgid, size_t* out_accid) {
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

  int cfgid = rr_viable_cfgid(); // per CPU
  if (cfgid == -1) {
    printf("SCHED: unable to grab cfgid\n");
    return false;
  }
  *out_cfgid = cfgid;
  printf("SCHED: set cfgid:%d\n", cfgid);

  if (!rr_is_viable_opcode(in_metadata->opcode, cfgid)) {
    printf("SCHED: unable to grab opcode:%d with cfgid:%d\n", in_metadata->opcode, cfgid);
    return false;
  }
  rr_set_opc(in_metadata->opcode, cfgid); // per CPU
  printf("SCHED: set opcode:%d\n", in_metadata->opcode);

  printf("SCHED: acquiring accid:%lu\n", cur_accid);
  assert(rr_acquire_single(cfgid, cur_accid)); // per CPU
  *out_accid = cur_accid;

  if (!was_waiting) {
    printf("SCHED: enqueuing queueid:%lu\n", cur_accid);
    elem_t e;
    e.metadata = (uint64_t)in_metadata | METADATA_MASK;
    assert(q_enqueue(&acc_running_q[cur_accid], e));
  } else {
    printf("SCHED: poke queueid:%lu to %lx\n", (uint64_t)in_metadata | METADATA_MASK);
    elem_t peeked_metadata;
    assert(q_peek(&acc_running_q[cur_accid], &peeked_metadata));
    assert(peeked_metadata.metadata == (uint64_t)in_metadata);
    peeked_metadata.metadata = (uint64_t)in_metadata | METADATA_MASK;
    assert(q_poke(&acc_running_q[cur_accid], peeked_metadata));
  }

  return true;
}

void pthread_cond_wait_wrapper(const char* prefix, pthread_cond_t *restrict cond, pthread_mutex_t *restrict mutex) {
  //pthread_cond_wait(cond, mutex);
  struct timespec timeout;
  clock_gettime(CLOCK_REALTIME, &timeout);
  timeout.tv_sec += 30;
  if (pthread_cond_timedwait(cond, mutex, &timeout)) {
    printf("TIMEOUT:%s: tid:%lu cpuid:%lu\n", prefix, pthread_self(), sched_getcpu());
    exit(1);
  }
}

bool grab_accelerator(metadata_t* in_metadata, uint8_t* accids, size_t accids_len, int32_t* out_cfgid, size_t* out_accid) {
  int cfgid = rr_viable_cfgid(); // per CPU
  if (cfgid == -1) {
    printf("SCHED: unable to grab cfgid\n");
    return false;
  }
  *out_cfgid = cfgid;
  printf("SCHED: set cfgid:%d\n", cfgid);

  if (!rr_is_viable_opcode(in_metadata->opcode, cfgid)) {
    printf("SCHED: unable to grab opcode:%d with cfgid:%d\n", in_metadata->opcode, cfgid);
    return false;
  }
  rr_set_opc(in_metadata->opcode, cfgid); // per CPU
  printf("SCHED: set opcode:%d\n", in_metadata->opcode);

  bool acq = false;
  for (size_t i = 0; i < accids_len; ++i) {
    printf("SCHED: attempting acquire of %lu\n", accids[i]);
    acq = rr_acquire_single(cfgid, accids[i]); // per CPU
    if (acq) {
      *out_accid = accids[i];
      printf("SCHED: acquired accid:%d to cfgid:%d\n", *out_accid, cfgid);
      break;
    }
  }

  return acq;
}

uint64_t get_est_acc_runtime_ns(metadata_t* metadata) {
  uint64_t prediction_ns = 0;
  switch (metadata->acc_type) {
    case PROTOBUF_SER:
      prediction_ns = proto_runtime_ns(true, (void*)metadata->descriptor_ptr, metadata->size);
      break;
    case PROTOBUF_DESER:
      prediction_ns = proto_runtime_ns(false, (void*)metadata->descriptor_ptr, metadata->size);
      break;
    case COMPRESS:
      prediction_ns = 0;
      break;
    case DECOMPRESS:
      prediction_ns = 0;
      break;
    case ENCRYPT:
      prediction_ns = encrypt_runtime_ns(true, metadata->size);
      break;
    case DECRYPT:
      prediction_ns = encrypt_runtime_ns(false, metadata->size);
      break;
  }

  printf("SCHED: acc_type:%d est_runtime_ns:%ld\n", metadata->acc_type, prediction_ns);
  return prediction_ns;
}

uint64_t get_est_cpu_runtime_ns(metadata_t* metadata) {
  return get_est_acc_runtime_ns(metadata) * 1000; // TODO: fix
}

// technically this is a combo of blocking if wanting an acc, or skipping if not
// if an accelerator is free:
//   mark global start time, est. acc. completion time in queue
// else:
//   get est. cpu completion time
//   if est. cpu completion time is < time to wait for an accelerator (gotten from summing all requests in acc queue - (current global time - global start time of current task running)) + est. acc. runtime
//     run on cpu
//   else:
//     enqueue on shortest accelerator queue, block until accelerator queue dequeued
bool grab_accelerator_queued_runtime(metadata_t* in_metadata, pthread_cond_t* queues_cond, bool* previously_enqueued, bool* run_on_cpu, uint8_t* accids, size_t accids_len, int32_t* out_cfgid, size_t* out_accid) {
  struct timespec time;
  clock_gettime(CLOCK_MONOTONIC, &time);
  uint64_t cur_time_ns = time.tv_sec * 1000000000 + time.tv_nsec;

  uint64_t est_acc_runtime_ns = get_est_acc_runtime_ns(in_metadata);

  size_t cur_accid;
  bool any_queue_empty = is_queue_empty(accids, accids_len, &cur_accid);
  bool was_waiting = false;

  if (!any_queue_empty) {
    printf("SCHED: no queues free\n");
    if (!(*previously_enqueued)) {
      printf("SCHED: hasn't been enqueued yet. maybe will enqueue or skip\n");

      bool run_on_acc = false;
      size_t best_queue_accid = accids[0];
      uint64_t cur_min = UINT64_MAX;
      uint64_t est_cpu_runtime_ns = get_est_cpu_runtime_ns(in_metadata);
      for (size_t i = 0; i < accids_len; ++i) {
        elem_t e;
        assert(q_peek(&acc_running_q[accids[i]], &e));
        bool is_running = ((e.metadata & METADATA_MASK) != 0);
        uint64_t acc_block_for_at_least_ns = q_sum(&acc_running_q[accids[i]]);
        uint64_t running_or_nextup_start_ns = e.ns_since_epoch;
        uint64_t time_since_first_acc_started_ns = cur_time_ns - running_or_nextup_start_ns;

         // only subtract if is actually running otherwise assume the worst
        int64_t ns_left_for_all_accs = acc_block_for_at_least_ns - (is_running ? time_since_first_acc_started_ns : 0);
        ns_left_for_all_accs = (ns_left_for_all_accs > 0 ? ns_left_for_all_accs : 0);
        printf("SCHED: queueid:%d is_running:%d sum:%ld timesincestart:%ld nsleft:%ld\n", accids[i], is_running, acc_block_for_at_least_ns, time_since_first_acc_started_ns, ns_left_for_all_accs);

        if (est_cpu_runtime_ns > (ns_left_for_all_accs + est_acc_runtime_ns)) {
          printf("SCHED: cpu expected to take longer than accs: cpu:%ld accs:%ld\n", est_cpu_runtime_ns, ns_left_for_all_accs + est_acc_runtime_ns);
          run_on_acc = true;
          // find the accid queue that would be fastest
          if (est_acc_runtime_ns < cur_min) {
            cur_min = est_acc_runtime_ns;
            best_queue_accid = accids[i];
            printf("SCHED: best_queue_accid:%d\n", best_queue_accid);
          }
        }
      }

      if (run_on_acc) {
        // enqueue on best_queue_accid's queue to wait (since we are guaranteed that something is before this)
        // block waiting for a change in the queue
        printf("SCHED: attempt enqueue into queue:%d for waiting\n", best_queue_accid);

        elem_t e;
        e.ns_since_epoch = cur_time_ns;
        e.est_acc_ns = est_acc_runtime_ns;
        e.metadata = (uint64_t)in_metadata & ~METADATA_MASK;
        if (q_enqueue(&acc_running_q[best_queue_accid], e)) {
          printf("SCHED: success, enqueued for waiting\n");
          *previously_enqueued = true;
        } else {
          printf("SCHED: unable to enqueue for waiting\n");
        }
        return false;
      } else {
        printf("SCHED: choose to run on cpu\n");
        *run_on_cpu = true;
        return true;
      }
    } else {
      printf("SCHED: was already enqueued\n"); // so check the 1st element
      was_waiting = is_ready_to_acquire(accids, accids_len, &cur_accid, in_metadata);
      if (!was_waiting) {
        printf("SCHED: this thread not waiting\n"); // elem didn't get to front of the line
        return false;
      }
    }
  }

  // if here then, a queue was empty OR (prev. enqueued and was_waiting to acquire)
  // either a q is empty (i.e. accel not in use) or a q's 1st element is waiting for accel and just needs to be allocated

  int cfgid = rr_viable_cfgid(); // per CPU
  if (cfgid == -1) {
    printf("SCHED: unable to grab cfgid\n");
    return false;
  }
  *out_cfgid = cfgid;
  printf("SCHED: set cfgid:%d\n", cfgid);

  if (!rr_is_viable_opcode(in_metadata->opcode, cfgid)) {
    printf("SCHED: unable to grab opcode:%d with cfgid:%d\n", in_metadata->opcode, cfgid);
    return false;
  }
  rr_set_opc(in_metadata->opcode, cfgid); // per CPU
  printf("SCHED: set opcode:%d\n", in_metadata->opcode);

  printf("SCHED: acquiring accid:%lu\n", cur_accid);
  assert(rr_acquire_single(cfgid, cur_accid)); // per CPU
  *out_accid = cur_accid;

  if (!was_waiting) {
    printf("SCHED: enqueuing queueid:%lu\n", cur_accid);
    elem_t e;
    e.ns_since_epoch = cur_time_ns;
    e.est_acc_ns = est_acc_runtime_ns;
    e.metadata = (uint64_t)in_metadata | METADATA_MASK;
    assert(q_enqueue(&acc_running_q[cur_accid], e));
  } else {
    printf("SCHED: poke queueid:%lu to %lx\n", (uint64_t)in_metadata | METADATA_MASK);
    elem_t peeked_metadata;
    assert(q_peek(&acc_running_q[cur_accid], &peeked_metadata));
    assert(peeked_metadata.metadata == (uint64_t)in_metadata);
    peeked_metadata.metadata = (uint64_t)in_metadata | METADATA_MASK;
    peeked_metadata.ns_since_epoch = cur_time_ns;
    assert(q_poke(&acc_running_q[cur_accid], peeked_metadata));
  }

  return true;
}

// has the potential to block
void schedule_run_on_acc(metadata_t* metadata) {
  setbuf(stdout, NULL);
  pthread_t tid = pthread_self();
  printf("SCHED: schedule_run_on_acc: tid:%lu coreid:%lu meta:%p acc_type:%d opcode:%d\n", tid, sched_getcpu(), metadata, metadata->acc_type, metadata->opcode);
  switch (metadata->acc_type) {
    case PROTOBUF_SER:
    case PROTOBUF_DESER:
      printf("SCHED: proto ser/des: size:%lu descptr:%p\n", metadata->size, metadata->descriptor_ptr);
      break;
    case COMPRESS:
      printf("SCHED: compress: size:%lu descptr:%p\n", metadata->size, metadata->descriptor_ptr);
      break;
    case DECOMPRESS:
      printf("SCHED: decompress: size:%lu descptr:%p compratio:%.2f\n", metadata->size, metadata->descriptor_ptr, metadata->compression_ratio);
      break;
    case ENCRYPT:
    case DECRYPT:
      printf("SCHED: enc: size:%lu\n", metadata->size);
      break;
    default:
      printf("SCHED: unsupported acc_type:%ld\n", metadata->acc_type);
  }

  metadata->given_accelerator = false;

#ifdef USE_REROCC
  // need to pin current thread id to a specific CPU s.t. acquire + release happen on the same CPU
  // otherwise you can have a race where CPUN can acquire and CPUM can release keeping the accelerator locked.
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  int cpuid = sched_getcpu();
  CPU_SET(cpuid, &cpuset); // set affinity to current cpu
  sched_setaffinity(0/*current thread*/, sizeof(cpu_set_t), &cpuset); // bind current thread to current cpu

  uint8_t* accids;
  uint8_t accids_len;
  get_accids(metadata->acc_type, &accids, &accids_len);

  // grabbing a cfgid, then accelerator, then opcode are combined (since a cfgid + accid + opc lifetimes are matched)
  int32_t cfgid;
  bool acq = false;
  size_t cur_accid;
#if defined(FCFS_SKIP)
  bool viable;
  cfgid = rr_viable_cfgid(); // this is per-core so no need to lock
  printf("SCHED: using cfgid:%d\n", cfgid);
  if (cfgid == -1) {
    metadata->given_accelerator = false;
    return;
  }

  for (size_t i = 0; i < accids_len; ++i) {
    printf("SCHED: attempting acquire of %lu\n", accids[i]);
    acq = rr_acquire_single(cfgid, accids[i]); // this is synch. across SoC so no need to lock
    if (acq) {
      cur_accid = accids[i];
      break;
    }
  }

  printf("SCHED: acq:%d cur_accid:%lu\n", acq, cur_accid);

  // order matters, need to acquire 1st
  // need to check if the accelerator is being used AND if the opcode is available
  viable = rr_is_viable_opcode(metadata->opcode, cfgid); // this is per-core so no need to lock
  printf("SCHED: viable:%d\n", viable);
  if (acq && viable) {
    metadata->given_accelerator = true;
    metadata->given_cfgid = cfgid;
    metadata->given_accid = cur_accid;
    rr_set_opc(metadata->opcode/*accelopcode*/, cfgid/*cfgreg*/);
    printf("SCHED: fully acquired: accid:%ld\n", cur_accid);
  } else if (acq) {
    printf("SCHED: releasing due to blocked opcode\n");
    // opcode not available since another acc has it on this core, drop the accelerator
    rr_release(cfgid);
  }

  metadata->blocked_cycles = 0;
  metadata->start_cycle = read_csr(time);
#elif defined(FCFS_BLOCK)
  uint64_t start = read_csr(time);
  pthread_mutex_lock(&main_mutex);
  acq = grab_accelerator(metadata, accids, accids_len, &cfgid, &cur_accid);
  while (!acq) {
    pthread_cond_wait_wrapper("atomic_acq", &main_cond, &main_mutex);
    printf("SCHED: wait over: tid:%lu\n", tid);
    acq = grab_accelerator(metadata, accids, accids_len, &cfgid, &cur_accid);
  }
  pthread_mutex_unlock(&main_mutex);
  uint64_t end = read_csr(time);

  printf("SCHED: fully acquired: accid:%ld\n", cur_accid);
  metadata->blocked_cycles = end - start;
  metadata->start_cycle = end;
  metadata->given_accelerator = true;
  metadata->given_cfgid = cfgid;
  metadata->given_accid = cur_accid;
#elif defined(FCFS_BLOCK_QUEUED)
  bool previously_enqueued = false;
  uint64_t start = read_csr(time);
  pthread_mutex_lock(&queues_mutex);
  acq = grab_accelerator_queued(metadata, &queues_cond, &previously_enqueued, accids, accids_len, &cfgid, &cur_accid); // can potentially signal
  while (!acq) {
    pthread_cond_wait_wrapper("atomic_acq", &queues_cond, &queues_mutex);
    printf("SCHED: wait over: tid:%lu\n", tid);
    acq = grab_accelerator_queued(metadata, &queues_cond, &previously_enqueued, accids, accids_len, &cfgid, &cur_accid); // can potentially signal
  }
  pthread_mutex_unlock(&queues_mutex);
  uint64_t end = read_csr(time);

  printf("SCHED: fully acquired: accid:%ld\n", cur_accid);
  metadata->blocked_cycles = end - start;
  metadata->start_cycle = end;
  metadata->given_accelerator = true;
  metadata->given_cfgid = cfgid;
  metadata->given_accid = cur_accid;
#elif defined(FCFS_RUNTIME_SKIP)
  bool previously_enqueued = false;
  bool run_on_cpu = false;
  uint64_t start = read_csr(time);
  pthread_mutex_lock(&queues_mutex);
  // in this case acq means "break out of loop" not that it acquired an accelerator
  acq = grab_accelerator_queued_runtime(metadata, &queues_cond, &previously_enqueued, &run_on_cpu, accids, accids_len, &cfgid, &cur_accid); // can potentially signal
  while (!acq) {
    pthread_cond_wait_wrapper("atomic_acq", &queues_cond, &queues_mutex);
    printf("SCHED: wait over: tid:%lu\n", tid);
    acq = grab_accelerator_queued_runtime(metadata, &queues_cond, &previously_enqueued, &run_on_cpu, accids, accids_len, &cfgid, &cur_accid); // can potentially signal
  }
  pthread_mutex_unlock(&queues_mutex);
  uint64_t end = read_csr(time);

  printf("SCHED: was acquired?: runcpu:%d accid:%ld\n", run_on_cpu, cur_accid);
  metadata->blocked_cycles = end - start;
  metadata->start_cycle = end;
  metadata->given_accelerator = !run_on_cpu;
  metadata->given_cfgid = cfgid;
  metadata->given_accid = cur_accid;
#endif

#else
  metadata->given_accelerator = true;
  metadata->given_accid = 0;
  metadata->blocked_cycles = 0;
  metadata->start_cycle = read_csr(time);
#endif
}

static void delay(void) {
  // inject latency to see any issues
  int r = rand() % 10000000;
  printf("SCHED: delay for %d\n", r);
  while (r > 0) {
    --r;
  }
}

// TODO: only acquire and release if another CPU wants it... i.e. pay penalty only once
void schedule_release_and_update(metadata_t* metadata) {
  setbuf(stdout, NULL); // TODO: remove this
  int coreid = sched_getcpu();
  pthread_t tid = pthread_self();
  printf("SCHED: release: tid:%lu coreid:%lu meta:%p given:%d accid:%ld\n", tid, coreid, metadata, metadata->given_accelerator, metadata->given_accid);
#ifdef USE_REROCC
  if (metadata->given_accelerator) {
    delay();
    printf("SCHED: doing release tid:%lu coreid:%lu cfgid:%ld accid:%ld\n", tid, coreid, metadata->given_cfgid, metadata->given_accid);
    // this is already globally synchronized
    rr_fence(metadata->given_cfgid); // wait until acc is idle (not busy) + cpu fence
    rr_release(metadata->given_cfgid); // clear accelerator tlb (i.e. acc sfence)
#if defined(FCFS_BLOCK)
    pthread_cond_broadcast(&main_cond); // something happened with accs, signal
#elif defined(FCFS_BLOCK_QUEUED)
    pthread_mutex_lock(&queues_mutex);
    printf("SCHED: release dequeue: tid:%lu coreid:%lu meta:%p given:%d accid:%ld\n", tid, coreid, metadata, metadata->given_accelerator, metadata->given_accid);
    assert(q_dequeue(&acc_running_q[metadata->given_accid]));
    pthread_cond_broadcast(&queues_cond); // something happened with queues+acc, signal
    pthread_mutex_unlock(&queues_mutex);
#elif defined(FCFS_RUNTIME_SKIP)
    pthread_mutex_lock(&queues_mutex);
    printf("SCHED: release dequeue: tid:%lu coreid:%lu meta:%p given:%d accid:%ld\n", tid, coreid, metadata, metadata->given_accelerator, metadata->given_accid);
    assert(q_dequeue(&acc_running_q[metadata->given_accid]));
    pthread_cond_broadcast(&queues_cond); // something happened with queues+acc, signal
    pthread_mutex_unlock(&queues_mutex);
#endif
  }

  // unbind current thread to current CPU (s.t. it can run on any CPU)
  // do after any rerocc stuff
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  sched_setaffinity(0/*current thread*/, sizeof(cpu_set_t), &cpuset);
  int cpuid = sched_getcpu();
#endif
  uint64_t runtime_cycles = read_csr(time) - metadata->start_cycle;
  printf("SCHED: release: acc_type:%d sched_rc:%ldc provided_rc:%ldc provided_ns:%ldns blocked_cycles:%ld\n",
         metadata->acc_type,
         runtime_cycles,
         metadata->runtime_cycles,
         metadata->runtime_ns,
         metadata->blocked_cycles);
}

#define MAX_THREADS (10000) // arb. to start

// HACKY:
// assuming shared across translation units
// assuming only written at start, can be read by multiple threads
typedef struct ser_data {
  volatile uint8_t** string_pointer_region;
  volatile uint8_t* string_data_region;
} ser_data_t;
ser_data_t sched_ser_data[MAX_THREADS];
size_t num_sched_ser_data = 0;
size_t sched_ser_data_idx = 0;

void PassSerInfoToScheduler(volatile uint8_t** string_pointer_region, volatile uint8_t* string_data_region) {
  assert(num_sched_ser_data < MAX_THREADS);
  sched_ser_data[num_sched_ser_data].string_pointer_region = string_pointer_region;
  sched_ser_data[num_sched_ser_data].string_data_region = string_data_region;
  ++num_sched_ser_data;
}

// TODO: threadsafe
void GetSerInfoFromScheduler(volatile uint8_t*** string_pointer_region_out, volatile uint8_t** string_data_region_out) {
  if (sched_ser_data_idx == num_sched_ser_data) {
    // rollover back to 0
    sched_ser_data_idx = 0;
  }
  ser_data_t* v = &sched_ser_data[sched_ser_data_idx];
  *string_pointer_region_out = v->string_pointer_region;
  *string_data_region_out = v->string_data_region;
  ++sched_ser_data_idx;
}

// HACKY:
// assuming shared across translation units
// assuming only written at start, can be read by multiple threads
typedef struct deser_data {
  volatile uint8_t* fixed_alloc_region;
  volatile uint8_t* array_alloc_region;
} deser_data_t;
deser_data_t sched_deser_data[MAX_THREADS];
size_t num_sched_deser_data = 0;
size_t sched_deser_data_idx = 0;

void PassDeserInfoToScheduler(volatile uint8_t* fixed_alloc_region, volatile uint8_t* array_alloc_region) {
  assert(num_sched_deser_data < MAX_THREADS);
  // TODO: use different struct. for now just reuse even w/ wrong names
  sched_deser_data[num_sched_deser_data].fixed_alloc_region = fixed_alloc_region;
  sched_deser_data[num_sched_deser_data].array_alloc_region = array_alloc_region;
  ++num_sched_deser_data;
}

// TODO: threadsafe
void GetDeserInfoFromScheduler(volatile uint8_t** fixed_alloc_region_out, volatile uint8_t** array_alloc_region_out) {
  if (sched_deser_data_idx == num_sched_deser_data) {
    // rollover back to 0
    sched_deser_data_idx = 0;
  }
  deser_data_t* v = &sched_deser_data[sched_deser_data_idx];
  *fixed_alloc_region_out = v->fixed_alloc_region;
  *array_alloc_region_out = v->array_alloc_region;
  ++sched_deser_data_idx;
}

typedef struct comp_data {
  uint8_t accid;
  volatile uint8_t* litbuf;
  size_t litbuf_sz;
  volatile uint8_t* seqbuf;
  size_t seqbuf_sz;
} comp_data_t;
comp_data_t sched_comp_data[MAX_COMPRESS_IDS];

// called from client/server
void CompressMemSetup(void) {
  const size_t buffer_size_wanted = 64UL << 10;
  for (size_t i = 0; i < MAX_COMPRESS_IDS; ++i) {
    sched_comp_data[i].accid = compress_accids[i];
    sched_comp_data[i].litbuf = AllocAligned(buffer_size_wanted, &(sched_comp_data[i].litbuf_sz));
    sched_comp_data[i].seqbuf = AllocAligned(buffer_size_wanted, &(sched_comp_data[i].seqbuf_sz));
  }
}

void GiveCompressMemTemps(uint8_t accid, volatile uint8_t** litbuf_out, size_t* litbuf_sz_out, volatile uint8_t** seqbuf_out, size_t* seqbuf_sz_out) {
  for (size_t i = 0; i < MAX_COMPRESS_IDS; ++i) {
    if (sched_comp_data[i].accid = accid) {
      *litbuf_out = sched_comp_data[i].litbuf;
      *litbuf_sz_out = sched_comp_data[i].litbuf_sz;
      *seqbuf_out = sched_comp_data[i].seqbuf;
      *seqbuf_sz_out = sched_comp_data[i].seqbuf_sz;
    }
  }
}

typedef struct decomp_data {
  uint8_t accid;
  volatile uint8_t* workspace;
  size_t workspace_sz;
} decomp_data_t;
decomp_data_t sched_decomp_data[MAX_DECOMPRESS_IDS];

// called from client/server
void DecompressMemSetup(void) {
  const size_t buffer_size_wanted = 64UL << 10; // must be large enough to hold all decompressed data
  for (size_t i = 0; i < MAX_DECOMPRESS_IDS; ++i) {
    sched_decomp_data[i].accid = decompress_accids[i];
    sched_decomp_data[i].workspace = AllocAligned(buffer_size_wanted, &(sched_decomp_data[i].workspace_sz));
  }
}

void GiveDecompressMemTemps(uint8_t accid, volatile uint8_t** workspace_out, size_t* workspace_sz_out) {
  for (size_t i = 0; i < MAX_DECOMPRESS_IDS; ++i) {
    if (sched_decomp_data[i].accid = accid) {
      *workspace_out = sched_decomp_data[i].workspace;
      *workspace_sz_out = sched_decomp_data[i].workspace_sz;
    }
  }
}

#endif
