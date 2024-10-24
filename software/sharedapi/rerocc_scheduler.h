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
  uint8_t given_accid;

  // provide to scheduler (before schedule_release_and_update)
  uint64_t runtime;
  bool enc_or_dec;
} metadata_t;

void init_scheduler(void);

// has the potential to block
// TODO: must be process and thread-safe
void schedule_run_on_acc(metadata_t* metadata);

// TODO: must be process and thread-safe
void schedule_release_and_update(metadata_t* metadata);

void PassSerInfoToScheduler(volatile uint8_t** string_pointer_region, volatile uint8_t* string_data_region);
// TODO: must be just thread-safe
void GetSerInfoFromScheduler(volatile uint8_t*** string_pointer_region_out, volatile uint8_t** string_data_region_out);

void PassDeserInfoToScheduler(volatile uint8_t* fixed_alloc_region, volatile uint8_t* array_alloc_region);
// TODO: must be just thread-safe
void GetDeserInfoFromScheduler(volatile uint8_t** fixed_alloc_region_out, volatile uint8_t** array_alloc_region_out);

void CompressMemSetup(void);
void GiveCompressMemTemps(uint8_t acc_id, volatile uint8_t** litbuf_out, size_t* litbuf_sz_out, volatile uint8_t** seqbuf_out, size_t* seqbuf_sz_out);
void DecompressMemSetup(void);
void GiveDecompressMemTemps(uint8_t acc_id, volatile uint8_t** workspace_out, size_t* workspace_sz_out);

#endif

#endif
