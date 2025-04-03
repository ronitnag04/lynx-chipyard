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
#include "c_time.h"

#ifndef USE_PRINTS
#define printf(...) (0)
#endif

#ifndef KEEP_ASSERTS
#define assert(x) (x)
#endif

#define MAX_PAYLOADS (1000)
typedef struct {
  bool filled;
  size_t len;
  uint64_t time_ns;
  uint64_t time_acc_ns;
} entry_t;
entry_t global_estimates[MAX_PAYLOADS];

typedef struct {
  size_t given_accelerator;
  size_t mid;
  size_t runtime_sch_ns;
  size_t runtime_ns;
} stats_t;
stats_t global_stats_entries[MAX_PAYLOADS];
size_t global_stats_i;

void Sched_get_estimates(const size_t mid, uint64_t* cpu_ns, uint64_t* acc_ns) {
  const entry_t* entry = &global_estimates[mid];
  *acc_ns = entry->time_acc_ns;
  *cpu_ns = entry->time_ns;
}

void Sched_init_estimates(const size_t id, const size_t len, const uint64_t time_ns, const uint64_t time_acc_ns) {
  assert(id < MAX_PAYLOADS);

  entry_t* entry = &global_estimates[id];
  if (entry->filled) {
    return; // keep old entry
  }

  entry->filled = true;
  entry->len = len;
  entry->time_ns = time_ns;
  entry->time_acc_ns = time_acc_ns;

  fprintf(stderr, "Adding est. CPU throughput: uniqid:%lu, len:%d, timens:%lu timeaccns:%lu\n", id, len, time_ns, time_acc_ns);
}

#define MAX_STATIC_ACCS (1000)
size_t global_max_acc_ids;
size_t global_acc_ids[MAX_STATIC_ACCS];
bool global_acc_busy[MAX_STATIC_ACCS]; // HACK: fake accelerator busy or not

pthread_mutex_t global_main_mutex;

FILE *global_fp;

#ifndef MAX_ACCS
#define MAX_ACCS (2)
#endif

void Sched_init(void) {
#ifdef USE_PRINTS
  // unbuffer stdout
  setbuf(stdout, NULL);
#endif

  global_stats_i = 0;
  // try to cache
  for (size_t i = 0; i < MAX_PAYLOADS; ++i) {
      global_stats_entries[i].given_accelerator = false;
  }

  // ok to clear twice (since we expect server will be setup before client)
  for (size_t i = 0; i < MAX_STATIC_ACCS; ++i) {
    global_acc_busy[i] = false;
  }

  global_max_acc_ids = MAX_ACCS;
  for (size_t i = 0; i < MAX_ACCS; ++i) {
    global_acc_ids[i] = i;
  }

  global_fp = fopen("sched.txt", "w");
  if (global_fp == NULL) {
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

  rc = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ADAPTIVE_NP);
  if (rc != 0) {
      perror("pthread_mutexattr_settype failed");
      pthread_mutexattr_destroy(&attr);
      exit(1);
  }

  rc = pthread_mutex_init(&global_main_mutex, &attr);
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

void Sched_plan(metadata_t* metadata) {
  metadata->given_start_ns = get_cur_ns();

#if defined(FCFS_SKIP)
  int64_t curaccid = -1;
  pthread_mutex_lock(&global_main_mutex);
  for (size_t i = 0; i < global_max_acc_ids; ++i) {
    printf("SCHED: attempting acquire of %lu\n", global_acc_ids[i]);
    const uint64_t accid = global_acc_ids[i];
    if (!global_acc_busy[accid]) {
      curaccid = accid;
      global_acc_busy[accid] = true;
      break;
    }
  }
  pthread_mutex_unlock(&global_main_mutex);

  if (curaccid != -1) {
    metadata->given_accelerator = true;
    metadata->given_accid = curaccid;
    printf("SCHED: acquired\n");
  } else {
    metadata->given_accelerator = false;
    printf("SCHED: not acquired\n");
  }
#elif defined(UNLIMITED)
  metadata->given_accelerator = true;
#else
  metadata->given_accelerator = false;
#endif
}

void Sched_override_plan(metadata_t* metadata, size_t override_accid) {
    metadata->given_accelerator = true;
    metadata->given_accid = override_accid;
}

void Sched_release_impl(metadata_t* metadata) {
  if (metadata->given_accelerator) {
    printf("SCHED: doing release tid:%lu cfgid:%ld accid:%ld\n", metadata->tid, metadata->given_cfgid, metadata->given_accid);
#if defined(FCFS_SKIP)
    pthread_mutex_lock(&global_main_mutex);
    global_acc_busy[metadata->given_accid] = false;
    pthread_mutex_unlock(&global_main_mutex);
#endif
  }
}

void Sched_mark_release(metadata_t* metadata) {
  const uint64_t runtime_sch_ns = get_cur_ns() - metadata->given_start_ns;
  printf("SCHED: release: ga:%d mid:%d sched_r_ns:%luns provided_r_ns:%luns",
         metadata->given_accelerator,
         metadata->mid,
         runtime_sch_ns,
         metadata->runtime_ns);
  stats_t* entry = &global_stats_entries[global_stats_i];
  entry->given_accelerator = metadata->given_accelerator;
  entry->mid               = metadata->mid;
  entry->runtime_sch_ns    = runtime_sch_ns;
  entry->runtime_ns        = metadata->runtime_ns;
  global_stats_i += 1;
}

void Sched_release(metadata_t* metadata) {
  printf("SCHED: release: tid:%lu meta:%p given:%d accid:%ld\n", metadata->tid, metadata, metadata->given_accelerator, metadata->given_accid);
  Sched_release_impl(metadata);
  Sched_mark_release(metadata);
}

void Sched_flush_file(void) {
    for (size_t i = 0; i < global_stats_i; i++) {
        stats_t* entry = &global_stats_entries[i];
        fprintf(global_fp, "%lu,%lu,%lu,%lu\n",
                entry->given_accelerator,
                entry->mid,
                entry->runtime_sch_ns,
                entry->runtime_ns
        );
    }
    global_stats_i = 0;
}
