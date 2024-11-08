#if !defined(__x86_64__)

#include <assert.h>
#include <semaphore.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#include "rerocc_scheduler.h"
#include "rerocc.h"
#include "helpers.h"
#include "queue.h"

#define MAX_PROTOBUF_SER_IDS (2)
uint8_t protobuf_ser_acc_ids[MAX_PROTOBUF_SER_IDS] = {6, 7};

#define MAX_PROTOBUF_DESER_IDS (2)
uint8_t protobuf_deser_acc_ids[MAX_PROTOBUF_DESER_IDS] = {4, 5};

#define MAX_COMPRESS_IDS (1)
uint8_t compress_acc_ids[MAX_COMPRESS_IDS] = {8};

#define MAX_DECOMPRESS_IDS (1)
uint8_t decompress_acc_ids[MAX_DECOMPRESS_IDS] = {9};

#define MAX_ENCRYPT_DECRYPT_IDS (2)
uint8_t encrypt_decrypt_acc_ids[MAX_ENCRYPT_DECRYPT_IDS] = {0, 1};

// fill arr + len with arr/len of the accelerator wanted
void get_acc_ids(acc_type_t acc_type, uint8_t** arr, uint8_t* len) {
  switch (acc_type) {
    case PROTOBUF_SER:
      *arr = protobuf_ser_acc_ids;
      *len = MAX_PROTOBUF_SER_IDS;
      break;
    case PROTOBUF_DESER:
      *arr = protobuf_deser_acc_ids;
      *len = MAX_PROTOBUF_DESER_IDS;
      break;
    case COMPRESS:
      *arr = compress_acc_ids;
      *len = MAX_COMPRESS_IDS;
      break;
    case DECOMPRESS:
      *arr = decompress_acc_ids;
      *len = MAX_DECOMPRESS_IDS;
      break;
    case ENCRYPT_DECRYPT:
      *arr = encrypt_decrypt_acc_ids;
      *len = MAX_ENCRYPT_DECRYPT_IDS;
      break;
    default:
      printf("SCHED: unsupported acc_type\n", acc_type);
  }
}

sem_t* sem = NULL;

// can share across processes w/ firemarshal/example-workloads/linux-hello
void init_scheduler(void) {
  if (sem == NULL) {
    sem = sem_open("/scheduler_sem", O_CREAT, 0644, 1); // by default shared between processes
  }
  printf("SCHED: setup %p\n", sem);
}

typedef struct proto_rt_entry_t {
  void* desc_ptr;
  size_t throughput_b_per_ns;
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
  return 0;
}

static size_t encrypt_runtime_ns(bool enc, size_t size) {
  //return size / (enc ? enc_throughput_b_per_ns : dec_throughput_b_per_ns) ;
  return size / 1;
}

// has the potential to block
//#define FCFS_SKIP
//#define FCFS_BLOCK
//#define FCFS_RUNTIME_SKIP

void schedule_run_on_acc(metadata_t* metadata) {
  printf("SCHED: schedule_run_on_acc enter\n");

  printf("SCHED: acc_type:%d opcode:%d\n", metadata->acc_type, metadata->opcode);
  printf("SCHED: proto: size:%lu descptr:%p\n", metadata->size, metadata->descriptor_ptr);
  printf("SCHED: compress: size:%lu descptr:%p compratio:%.2f\n", metadata->size, metadata->descriptor_ptr, metadata->compression_ratio);
  printf("SCHED: compress: size:%lu\n", metadata->size);

  sem_wait(sem);

  metadata->given_accelerator = false;

#ifdef USE_REROCC
  uint8_t* accel_ids;
  uint8_t accel_ids_len;
  get_acc_ids(metadata->acc_type, &accel_ids, &accel_ids_len);

  // uint32_t i = 10000;
  // while (i > 0) {
  //   printf("delay:%d\n", i);
  //   --i;
  // }

  printf("SCHED: obtained accel ids + len\n");

  // grabbing a cfgid, then accelerator, then opcode are combined (since a cfgid + accid + opc lifetimes are matched)
  int32_t cfgid;
  bool acq = false;
  size_t cur_acc_id;
#if defined(FCFS_SKIP)
  bool viable;
  cfgid = rr_viable_cfgid();
  printf("SCHED: using cfgid: %d\n", cfgid);
  if (cfgid == -1) {
    metadata->given_accelerator = false;
    return;
  }

  for (size_t i = 0; i < accel_ids_len; ++i) {
    printf("SCHED: attempting acquire of %lu\n", accel_ids[i]);
    acq = rr_acquire_single(cfgid, accel_ids[i]);
    if (acq) {
      cur_acc_id = accel_ids[i];
      break;
    }
  }

  printf("SCHED: acq:%d cur_acc_id:%lu\n", acq, cur_acc_id);

  // order matters, need to acquire 1st
  // need to check if the accelerator is being used AND if the opcode is available
  viable = rr_is_viable_opcode(metadata->opcode, cfgid);
  printf("SCHED: viable:%d\n", viable);
  if (acq && viable) {
    metadata->given_accelerator = true;
    metadata->given_cfgid = cfgid;
    metadata->given_accid = cur_acc_id;
    rr_set_opc(metadata->opcode/*accelopcode*/, cfgid/*cfgreg*/);
    printf("SCHED: fully acquired\n");
  } else if (acq) {
    printf("SCHED: releasing due to blocked opcode\n");
    // opcode not available since another acc has it on this core, drop the accelerator
    rr_release(cfgid);
  }

  metadata->blocked_cycles = 0;
  metadata->start_acc_cycle = read_csr(time);
#elif defined(FCFS_BLOCK)
  uint64_t start = read_csr(time);
  // TODO: switch to semaphore based? signal to linux that this can context switch
  do {
    cfgid = rr_viable_cfgid();
    printf("SCHED: cfgid:%d\n", cfgid);
    if (cfgid != -1) {
      for (size_t i = 0; i < accel_ids_len; ++i) {
        printf("SCHED: attempting acquire of %lu\n", accel_ids[i]);
        acq = rr_acquire_single(cfgid, accel_ids[i]);
        if (acq) {
          cur_acc_id = accel_ids[i];
          break;
        }
      }

      printf("SCHED: acq:%d cur_acc_id:%lu\n", acq, cur_acc_id);

      if (!acq) {
        cfgid = -1;
      } else {
        if (!rr_is_viable_opcode(metadata->opcode, cfgid)) {
          printf("SCHED: releasing due to blocked opcode\n");
          // opcode not available since another acc has it on this core, drop the accelerator
          rr_release(cfgid);
          cfgid = -1;
        }
      }
    }
  } while (cfgid == -1);
  uint64_t end = read_csr(time);

  metadata->blocked_cycles = end - start;
  metadata->start_acc_cycle = end;
  metadata->given_accelerator = true;
  metadata->given_cfgid = cfgid;
  metadata->given_accid = cur_acc_id;
  rr_set_opc(metadata->opcode/*accelopcode*/, cfgid/*cfgreg*/);
#elif defined(FCFS_RUNTIME_SKIP)
  // size_t prediction_ns = 0;
  // switch (metadata->acc_type) {
  //   case PROTOBUF_SER:
  //     prediction_ns = proto_runtime_ns(true, metadata->descriptor_ptr, metadata->size);
  //     break;
  //   case PROTOBUF_DESER:
  //     prediction_ns = proto_runtime_ns(false, metadata->descriptor_ptr, metadata->size);
  //     break;
  //   case COMPRESS:
  //     prediction_ns = 0;
  //     break;
  //   case DECOMPRESS:
  //     prediction_ns = 0;
  //     break;
  //   case ENCRYPT_DECRYPT:
  //     prediction_ns = encrypt_runtime_ns(true, metadata_size); // TODO: distinguish between enc/dec
  //     break;
  // }

  // bool viable;
  // cfgid = rr_viable_cfgid();
  // if (cfgid == -1) {
  //   metadata->given_accelerator = false;
  //   return;
  // }
  //
  // for (size_t i = 0; i < accel_ids_len; ++i) {
  //   acq = rr_acquire_single(cfgid, accel_ids[i]);
  //   if (acq) {
  //     cur_acc_id = accel_ids[i];
  //     break;
  //   }
  // }
  //
  // // order matters, need to acquire 1st
  // // need to check if the accelerator is being used AND if the opcode is available
  // viable = rr_is_viable_opcode(metadata->opcode, cfgid);
  // if (acq && viable) {
  //   metadata->given_accelerator = true;
  //   metadata->given_cfgid = cfgid;
  //   metadata->given_accid = cur_acc_id;
  //   rr_set_opc(metadata->opcode/*accelopcode*/, cfgid/*cfgreg*/);
  // }
  //
#endif

#else
  metadata->given_accelerator = true;
  metadata->given_accid = 0;
  metadata->blocked_cycles = 0;
  metadata->start_acc_cycle = read_csr(time);
#endif

  // i = 10000;
  // while (i > 0) {
  //   printf("delay:%d\n", i);
  //   --i;
  // }

  sem_post(sem);
}

void schedule_release_and_update(metadata_t* metadata) {
#ifdef USE_REROCC
  // this is already globally synchronized
  rr_fence(metadata->given_cfgid); // clear tlb
  rr_release(metadata->given_cfgid); // TODO: do we need to fence before this? does this clear tlb?
  printf("SCHED: release\n");

  // uint64_t size;
  // const void* descriptor_ptr; // also compression (for when comp_ratio can't be determined immediately)
  // double compression_ratio;

  // f(descriptor_ptr, size) = runtime

  // // TODO: currently this saturates, do something better
  // if (all_acc_runtimes[metadata->acc_type].count < 1000) {
  //   size_t count = all_acc_runtimes[metadata->acc_type].count + 1;
  //   size_t avg_runtime_ns = all_acc_runtimes[metadata->acc_type].avg_runtime_ns;
  //   all_acc_runtimes[metadata->acc_type].count += count;
  //   all_acc_runtimes[metadata->acc_type].avg_runtime_ns = ((avg_runtime_ns * count) + metadata->runtime) / count;
  // }
#endif
  uint64_t runtime_cycles = metadata->start_acc_cycle - read_csr(time);
  printf("SCHED: release: atyp:%d rc:%ldc,%ldns bc:%ld\n", metadata->acc_type, runtime_cycles, metadata->runtime, metadata->blocked_cycles);
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
  uint8_t acc_id;
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
    sched_comp_data[i].acc_id = compress_acc_ids[i];
    sched_comp_data[i].litbuf = AllocAligned(buffer_size_wanted, &(sched_comp_data[i].litbuf_sz));
    sched_comp_data[i].seqbuf = AllocAligned(buffer_size_wanted, &(sched_comp_data[i].seqbuf_sz));
  }
}

void GiveCompressMemTemps(uint8_t acc_id, volatile uint8_t** litbuf_out, size_t* litbuf_sz_out, volatile uint8_t** seqbuf_out, size_t* seqbuf_sz_out) {
  for (size_t i = 0; i < MAX_COMPRESS_IDS; ++i) {
    if (sched_comp_data[i].acc_id = acc_id) {
      *litbuf_out = sched_comp_data[i].litbuf;
      *litbuf_sz_out = sched_comp_data[i].litbuf_sz;
      *seqbuf_out = sched_comp_data[i].seqbuf;
      *seqbuf_sz_out = sched_comp_data[i].seqbuf_sz;
    }
  }
}

typedef struct decomp_data {
  uint8_t acc_id;
  volatile uint8_t* workspace;
  size_t workspace_sz;
} decomp_data_t;
decomp_data_t sched_decomp_data[MAX_DECOMPRESS_IDS];

// called from client/server
void DecompressMemSetup(void) {
  const size_t buffer_size_wanted = 64UL << 10; // must be large enough to hold all decompressed data
  for (size_t i = 0; i < MAX_DECOMPRESS_IDS; ++i) {
    sched_decomp_data[i].acc_id = decompress_acc_ids[i];
    sched_decomp_data[i].workspace = AllocAligned(buffer_size_wanted, &(sched_decomp_data[i].workspace_sz));
  }
}

void GiveDecompressMemTemps(uint8_t acc_id, volatile uint8_t** workspace_out, size_t* workspace_sz_out) {
  for (size_t i = 0; i < MAX_DECOMPRESS_IDS; ++i) {
    if (sched_decomp_data[i].acc_id = acc_id) {
      *workspace_out = sched_decomp_data[i].workspace;
      *workspace_sz_out = sched_decomp_data[i].workspace_sz;
    }
  }
}

#endif
