#ifndef REROCC_SCHEDULER_H
#define REROCC_SCHEDULER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct {
  bool given_accelerator;
  uint64_t given_start_ns;
  size_t given_accid;
  uint64_t runtime_ns;
  size_t mid;
} metadata_t;

void Sched_init(void);
void Sched_plan(metadata_t* metadata);
void Sched_release(metadata_t* metadata);

void Sched_override_plan(metadata_t* metadata, size_t override_accid);
void Sched_mark_release(metadata_t* metadata);
void Sched_release_impl(metadata_t* metadata);

void Sched_flush_file(void);

void Sched_init_estimates(const size_t id, const size_t len, const uint64_t time_ns, const uint64_t time_acc_ns);
void Sched_get_estimates(const size_t mid, uint64_t* cpu_ns, uint64_t* acc_ns);

#endif
