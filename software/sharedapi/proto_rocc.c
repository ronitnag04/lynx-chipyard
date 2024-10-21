#if !defined(__x86_64__)

#if defined(USE_PROTO_SER_ACC) || defined(USE_PROTO_DES_ACC)

#include <stdbool.h>
#include <malloc.h>
#include <inttypes.h>
#include <assert.h>
#include "rocc.h"
#include "proto_rocc.h"

#define FUNCT_SER_SFENCE 0
#define FUNCT_HASBITS_INFO 1
#define FUNCT_DO_PROTO_SERIALIZE 2
#define FUNCT_SER_MEM_SETUP 3
#define FUNCT_SER_CHECK_COMPLETION 4

#define PAGESIZE_BYTES 4096
#define MAX_BUS_WIDTH 256

#define accprintf(...) (0)

static inline void ForcePagedIn(void* region, size_t size) {
#if defined(__linux) && defined(USE_MLOCK)
    if (mlock(region, size) != 0) {
      accprintf("E: mlock failed: unable to pin pages\n");
    }
#else
  for (size_t i = 0; i < size; i += PAGESIZE_BYTES) {
    ((char*)region)[i] = 0;
  }
#endif
}

static inline size_t MultipleOf(size_t in, size_t multiple_of) {
  assert(multiple_of >= 0);
  return ((in + multiple_of - 1) / multiple_of) * multiple_of;
}

static void* AllocAligned(size_t size, size_t* alloc_size) {
  size_t mult_size = MultipleOf(size, MAX_BUS_WIDTH); // round up to nearest multiple of MAX_BUS_WIDTH (buswidth) (also 64 since accelerator deals with 64 only)
  void* region = memalign(PAGESIZE_BYTES, mult_size);
  if (region == NULL) {
    accprintf("E: malloc failed: nullptr returned\n");
  }
  *alloc_size = mult_size;
  return region;
}

void SerClearAccelTLB(void) {
    ROCC_INSTRUCTION(PROTOACC_SER_OPCODE, FUNCT_SER_SFENCE); // should clear the accel TLB
}

// will fill string_pointer_region, string_data_region with allocated pointers
void SerCreateArenas(size_t num_string_pointers, size_t total_string_data_bytes, volatile char*** string_pointer_region_out, volatile char** string_data_region_out) {
    accprintf("I: NumStrs:%ld TotalBytes:%ld\n", num_string_pointers, total_string_data_bytes);

    // string data allocation
    size_t string_data_region_size;
    char* string_data_region = (char*)AllocAligned(sizeof(char) * total_string_data_bytes, &string_data_region_size);
    ForcePagedIn((void*)string_data_region, string_data_region_size);
    uint64_t string_data_region_ptr_as_int = (uint64_t)string_data_region;
    uint64_t string_data_region_ptr_as_int_tail = string_data_region_ptr_as_int + (uint64_t)string_data_region_size;
    accprintf("I: SDR: %lld bytes alloc'ed, tail at 0x%016llx, start at 0x%016llx\n", (uint64_t)string_data_region_size, string_data_region_ptr_as_int_tail, string_data_region_ptr_as_int);

    // string pointer allocation
    size_t string_pointer_region_size;
    char** string_pointer_region = (char**)AllocAligned(sizeof(char*) * num_string_pointers, &string_pointer_region_size);
    ForcePagedIn((void*)string_pointer_region, string_pointer_region_size);
    // TODO: unsure what this does exactly
    string_pointer_region[0] = (char*)string_data_region_ptr_as_int_tail;
    string_pointer_region += 1;
    uint64_t string_pointer_region_ptr_as_int = (uint64_t)string_pointer_region;
    accprintf("I: SPR: %lld byte alloc'ed, starting at 0x%016llx\n", (uint64_t)string_pointer_region_size, string_pointer_region_ptr_as_int);

    assert((string_data_region_ptr_as_int_tail & 0x7) == 0x0);
    assert((string_pointer_region_ptr_as_int & 0x7) == 0x0);

    *string_data_region_out = (volatile char*)string_data_region_ptr_as_int_tail;
    *string_pointer_region_out = (volatile char**)string_pointer_region;
}

void SerSetArenaInfoAndClearTLB(volatile char** string_pointer_region, volatile char* string_data_region) {
  SerClearAccelTLB();
  ROCC_INSTRUCTION_SS(PROTOACC_SER_OPCODE, (uint64_t)string_data_region, (uint64_t)string_pointer_region, FUNCT_SER_MEM_SETUP);
}

// OLD
volatile char ** AccelSetupAllocRegionSerializer(size_t num_string_pointers, size_t total_string_data_bytes) {
    volatile char** spr; // string ptr region
    volatile char* sdr; // string data region
    SerCreateArenas(num_string_pointers, total_string_data_bytes, &spr, &sdr);

    SerSetArenaInfoAndClearTLB(spr, sdr);
    return spr;
}

volatile char * BlockOnSerializedValue(volatile char ** ptrs, int index) {
    accprintf("SerAcc: CheckCompletion\n");
    uint64_t retval;
    ROCC_INSTRUCTION_D(PROTOACC_SER_OPCODE, retval, FUNCT_SER_CHECK_COMPLETION);
    asm volatile ("fence");

    accprintf("SerAcc: StartLoop: inptr: %p, index: %d, loopaddr: %p, valat0: 0x%lx %p\n", ptrs, index, &ptrs[index], (uint64_t)ptrs[0], &ptrs[0]);

    while (ptrs[index] == 0) {
        asm volatile ("fence");
    }

    accprintf("SerAcc: DoneLoop done loop\n");

    return ptrs[index];
}

size_t GetSerializedLength(volatile char ** ptrs, int index) {
    return (size_t)(ptrs[index-1] - ptrs[index]);
}

void AccelSerializeToString_Helper(const void * descriptor_table_ptr, void * src_base_addr) {
    uint64_t* access_descr_ptr = (uint64_t*)descriptor_table_ptr;
    uint64_t hasbits_offset = access_descr_ptr[2];
    uint64_t min_max_fieldno = access_descr_ptr[3];

    accprintf("Starting serialization: DescPtr:%p MsgPtr:%p\n", descriptor_table_ptr, src_base_addr);

    ROCC_INSTRUCTION_SS(PROTOACC_SER_OPCODE, hasbits_offset, min_max_fieldno, FUNCT_HASBITS_INFO);
    ROCC_INSTRUCTION_SS(PROTOACC_SER_OPCODE, descriptor_table_ptr, src_base_addr, FUNCT_DO_PROTO_SERIALIZE);
}

#define FUNCT_SFENCE 0
#define FUNCT_PROTO_PARSE_INFO 1
#define FUNCT_DO_PROTO_PARSE 2
#define FUNCT_MEM_SETUP 3
#define FUNCT_CHECK_COMPLETION 4

void DeserClearAccelTLB(void) {
    ROCC_INSTRUCTION(PROTOACC_OPCODE, FUNCT_SFENCE); // should clear the accel TLB
}

// will fill fixed_alloc_region, array_alloc_region with allocated pointers
void DeserCreateArenas(size_t region_size_bytes, volatile char** fixed_alloc_region_out, volatile char** array_alloc_region_out) {
    accprintf("I: TotalBytes:%ld\n", region_size_bytes);

    // fixed alloc region allocation
    size_t fixed_alloc_region_size;
    char* fixed_alloc_region = (char*)AllocAligned(sizeof(char) * region_size_bytes, &fixed_alloc_region_size);
    ForcePagedIn((void*)fixed_alloc_region, fixed_alloc_region_size);
    uint64_t fixed_alloc_region_ptr_as_int = (uint64_t)fixed_alloc_region;
    accprintf("I: FAR: %lld bytes alloc'ed, start at 0x%016llx\n", (uint64_t)fixed_alloc_region_size, fixed_alloc_region_ptr_as_int);

    // array alloc region allocation
    size_t array_alloc_region_size;
    char* array_alloc_region = (char**)AllocAligned(sizeof(char) * region_size_bytes, &array_alloc_region_size);
    ForcePagedIn((void*)array_alloc_region, array_alloc_region_size);
    uint64_t array_alloc_region_ptr_as_int = (uint64_t)array_alloc_region;
    accprintf("I: AAR: %lld byte alloc'ed, starting at 0x%016llx\n", (uint64_t)array_alloc_region_size, array_alloc_region_ptr_as_int);

    assert((fixed_alloc_region_ptr_as_int & 0x7) == 0x0);
    assert((array_alloc_region_ptr_as_int & 0x7) == 0x0);

    *fixed_alloc_region_out = (volatile char*)fixed_alloc_region;
    *array_alloc_region_out = (volatile char*)array_alloc_region;
}

void DeserSetArenaInfoAndClearTLB(volatile char* fixed_alloc_region, volatile char* array_alloc_region) {
  DeserClearAccelTLB();
  ROCC_INSTRUCTION_SS(PROTOACC_OPCODE, (uint64_t)fixed_alloc_region, (uint64_t)array_alloc_region, FUNCT_MEM_SETUP);
}

// OLD
void AccelSetupFixedAllocRegion(size_t region_size_bytes) {
    volatile char* far; // fixed alloc region
    volatile char* aar; // array alloc region
    DeserCreateArenas(region_size_bytes, &far, &aar);

    DeserSetArenaInfoAndClearTLB(far, aar);
}

void AccelParseFromString_Helper(const void * descriptor_table_ptr, void * dest_base_addr, const void * base_ptr, size_t input_length) {
    if (input_length == 0) {
        return;
    }

    uint64_t* access_descr_ptr = (uint64_t*)descriptor_table_ptr;
    uint64_t min_field_no = access_descr_ptr[3] >> 32;
    uint64_t low32_mask_internal = 0x00000000FFFFFFFFL;
    uint64_t min_field_no_and_input_length = (min_field_no << 32) | (input_length & low32_mask_internal);

    accprintf("Starting deserialization: DescPtr:%p InStrPtr:%p DestPtr:%p\n", descriptor_table_ptr, base_ptr, dest_base_addr);

    ROCC_INSTRUCTION_SS(PROTOACC_OPCODE, descriptor_table_ptr, dest_base_addr, FUNCT_PROTO_PARSE_INFO);
    ROCC_INSTRUCTION_SS(PROTOACC_OPCODE, base_ptr, min_field_no_and_input_length, FUNCT_DO_PROTO_PARSE);
}

uint64_t BlockOnDeserialization() {
    uint64_t retval;
    ROCC_INSTRUCTION_D(PROTOACC_OPCODE, retval, FUNCT_CHECK_COMPLETION);
    asm volatile ("fence");
    return retval;
}

#endif

#endif
