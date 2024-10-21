#if !defined(__x86_64__)

#include <assert.h>
#include <semaphore.h>
#include <fcntl.h>
#include "rerocc_scheduler.h"
#include "rerocc.h"

#define MAX_PROTOBUF_SER_IDS (1)
uint8_t protobuf_ser_acc_ids[MAX_PROTOBUF_SER_IDS] = {1};

#define MAX_PROTOBUF_DESER_IDS (1)
uint8_t protobuf_deser_acc_ids[MAX_PROTOBUF_DESER_IDS] = {1};

#define MAX_COMPRESS_IDS (1)
uint8_t compress_acc_ids[MAX_COMPRESS_IDS] = {1};

#define MAX_DECOMPRESS_IDS (1)
uint8_t decompress_acc_ids[MAX_DECOMPRESS_IDS] = {1};

#define MAX_ENCRYPT_DECRYPT_IDS (1)
uint8_t encrypt_decrypt_acc_ids[MAX_ENCRYPT_DECRYPT_IDS] = {1};

// fill arr + len with arr/len of the accelerator wanted
void get_acc_ids(acc_type_t acc_type, uint8_t** arr, uint8_t* len) {
  switch (acc_type) {
    case PROTOBUF_SER:
      *arr = protobuf_ser_acc_ids;
      *len = MAX_PROTOBUF_SER_IDS;
    case PROTOBUF_DESER:
      *arr = protobuf_deser_acc_ids;
      *len = MAX_PROTOBUF_DESER_IDS;
    case COMPRESS:
      *arr = compress_acc_ids;
      *len = MAX_COMPRESS_IDS;
    case DECOMPRESS:
      *arr = decompress_acc_ids;
      *len = MAX_DECOMPRESS_IDS;
    case ENCRYPT_DECRYPT:
      *arr = encrypt_decrypt_acc_ids;
      *len = MAX_ENCRYPT_DECRYPT_IDS;
  }
}

sem_t* sem = NULL;

// can share across processes w/ firemarshal/example-workloads/linux-hello
void init_scheduler(void) {
  if (sem == NULL) {
    sem = sem_open("/scheduler_sem", O_CREAT, 0644, 1); // by default shared between processes
  }

  // if (sptr == NULL) {
  //   // only 1 thread can setup shared memory at a time
  //   sem_wait(sem);
  //
  //   int fd;
  //   fd = shm_open("/scheduler", O_RDWR | O_CREAT, S_IRUSR | S_IWUSR); // TODO: unsure what S_... flags are
  //   if (fd == -1) {
  //     exit(-1);
  //   }
  //
  //   if (ftruncate(fd, sizeof(scheduler_t)) == -1) {
  //     exit(-1);
  //   }
  //
  //   sptr = mmap(NULL, sizeof(scheduler_t), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  //   if (sptr == MAP_FAILED) {
  //     exit(-1);
  //   }
  //
  //   sptr->len = 0;
  //
  //   sem_post(sem);
  // }
}

// has the potential to block
void schedule_run_on_acc(metadata_t* metadata) {
  sem_wait(sem);
  int32_t cfgid = rr_viable_cfgid();
  if (cfgid == -1) {
    metadata->given_accelerator = false;
    return;
  }

  uint8_t* accel_ids;
  uint8_t accel_ids_len;
  get_acc_ids(metadata->acc_type, &accel_ids, &accel_ids_len);

  bool acq = false;
  size_t cur_acc_id;
  bool cur_acq;
  for (size_t i = 0; i < accel_ids_len; ++i) {
    acq = rr_acquire_single(cfgid, accel_ids[i]);
    if (acq) {
      cur_acc_id = accel_ids[i];
      break;
    }
  }

  // need to check if the accelerator is being used AND if the opcode is available
  bool viable = rr_is_viable_opcode(metadata->opcode, cfgid);

  if (acq && viable) {
    metadata->given_accelerator = true;
    metadata->given_cfgid = cfgid;
    rr_set_opc(metadata->opcode/*accelopcode*/, cfgid/*cfgreg*/);
  }
  sem_post(sem);
}

void schedule_release_and_update(metadata_t* metadata) {
  // this is already globally synchronized
  rr_release(metadata->given_cfgid); // this should clear the rerocc L2 TLB
}

#define MAX_THREADS (10000) // arb. to start

// HACKY:
// assuming shared across translation units
// assuming only written at start, can be read by multiple threads
typedef struct ser_data {
  volatile char** string_pointer_region;
  volatile char* string_data_region;
} ser_data_t;
ser_data_t sched_ser_data[MAX_THREADS];
size_t num_sched_ser_data = 0;
size_t sched_ser_data_idx = 0;

void PassSerInfoToScheduler(volatile char** string_pointer_region, volatile char* string_data_region) {
  assert(num_sched_ser_data < MAX_THREADS);
  sched_ser_data[num_sched_ser_data].string_pointer_region = string_pointer_region;
  sched_ser_data[num_sched_ser_data].string_data_region = string_data_region;
  ++num_sched_ser_data;
}

// TODO: threadsafe
void GetSerInfoFromScheduler(volatile char*** string_pointer_region_out, volatile char** string_data_region_out) {
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
  volatile char* fixed_alloc_region;
  volatile char* array_alloc_region;
} deser_data_t;
deser_data_t sched_deser_data[MAX_THREADS];
size_t num_sched_deser_data = 0;
size_t sched_deser_data_idx = 0;

void PassDeserInfoToScheduler(volatile char* fixed_alloc_region, volatile char* array_alloc_region) {
  assert(num_sched_deser_data < MAX_THREADS);
  // TODO: use different struct. for now just reuse even w/ wrong names
  sched_deser_data[num_sched_deser_data].fixed_alloc_region = fixed_alloc_region;
  sched_deser_data[num_sched_deser_data].array_alloc_region = array_alloc_region;
  ++num_sched_deser_data;
}

// TODO: threadsafe
void GetDeserInfoFromScheduler(volatile char** fixed_alloc_region_out, volatile char** array_alloc_region_out) {
  if (sched_deser_data_idx == num_sched_deser_data) {
    // rollover back to 0
    sched_deser_data_idx = 0;
  }
  deser_data_t* v = &sched_deser_data[sched_deser_data_idx];
  *fixed_alloc_region_out = v->fixed_alloc_region;
  *array_alloc_region_out = v->array_alloc_region;
  ++sched_deser_data_idx;
}

#endif
