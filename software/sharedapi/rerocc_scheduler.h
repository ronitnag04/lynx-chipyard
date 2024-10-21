#ifndef REROCC_SCHEDULER_H
#define REROCC_SCHEDULER_H

#if !defined(__x86_64__)

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef enum acc_type {
  PROTOBUF_SER,
  PROTOBUF_DESER,
  COMPRESS,
  DECOMPRESS,
  ENCRYPT_DECRYPT,
} acc_type_t;

// fill arr + len with arr/len of the accelerator wanted
// TODO: must be thread-safe
void get_acc_ids(acc_type_t acc_type, uint8_t** arr, uint8_t* len);

typedef struct metadata {
  // provide to scheduler (before schedule_run_on_acc)
  acc_type_t acc_type;
  uint8_t opcode;

  // proto specific provide to scheduler (before schedule_run_on_acc)
  uint64_t size;
  const void* descriptor_ptr;

  // given by scheduler (after schedule_run_on_acc)
  bool given_accelerator;
  uint8_t given_cfgid;

  // provide to scheduler (before schedule_release_and_update)
  uint64_t runtime;
} metadata_t;

void init_scheduler(void);

// has the potential to block
// TODO: must be process and thread-safe
void schedule_run_on_acc(metadata_t* metadata);

// TODO: must be process and thread-safe
void schedule_release_and_update(metadata_t* metadata);

void PassSerInfoToScheduler(volatile char** string_pointer_region, volatile char* string_data_region);
// TODO: must be just thread-safe
void GetSerInfoFromScheduler(volatile char*** string_pointer_region_out, volatile char** string_data_region_out);

void PassDeserInfoToScheduler(volatile char* fixed_alloc_region, volatile char* array_alloc_region);
// TODO: must be just thread-safe
void GetDeserInfoFromScheduler(volatile char** fixed_alloc_region_out, volatile char** array_alloc_region_out);

#endif

#endif
