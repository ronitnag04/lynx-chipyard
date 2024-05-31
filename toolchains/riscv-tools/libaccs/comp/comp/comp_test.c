// The following is a RISC-V program to test the functionality of the
// dummy RoCC accelerator.
// Compile with riscv64-unknown-elf-gcc fool_rocc_test.c
// Run with spike --extension=fool pk a.out

#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <malloc.h>
#include <inttypes.h>

#include "rocc.h"
#include "encoding.h"
#include "benchmark_data_0.h"
// Get benchmark_uncompressed_data_0 and benchmark_compressed_data_0

#define PAGESIZE_BYTES 4096

// Comp's opcode is 1. It Uses opcode=0 funct[6]==1 as extended opcode 1
#define COMP_OPCODE 0
#define COMP_EXTEND 64

unsigned char* MemSetup(size_t write_region_size){
  size_t regionsize = sizeof(char) * (write_region_size);
  unsigned char* fixed_alloc_region = (unsigned char*)memalign(PAGESIZE_BYTES, regionsize);
  for (uint64_t i = 0; i < regionsize; i += PAGESIZE_BYTES) {
    fixed_alloc_region[i] = 0;
  }
  uint64_t fixed_ptr_as_int = (uint64_t)fixed_alloc_region;
  assert((fixed_ptr_as_int & 0x7) == 0x0);
  printf("constructed %" PRIu64 " byte region, starting at 0x%016" PRIx64 ", paged-in, for accel\n",
    (uint64_t)regionsize, fixed_ptr_as_int);
  return fixed_alloc_region;
};

int main() {
  // Set literal buffer and sequence buffer
  printf("Literal and sequence buffer init\n");
  size_t buffersize = 1<<16;
  unsigned char* litbuf = MemSetup(buffersize);
  unsigned char* seqbuf = MemSetup(buffersize);
  // Set result area
  printf("Fn 0: Fence\n");
  ROCC_INSTRUCTION(COMP_OPCODE, 0); //ROCC_INSTRUCTION_I_I_I(COMP_OPCODE, 0, 0, 0, 0);
  printf("Write region init\n");
  size_t resultsize = (1<<16) + 4096;
  unsigned char* result_area = MemSetup(resultsize);

  // Set dynamic hash table size
  printf("Fn 9: Set dynamic hash table size (log 2)\n");
  ROCC_INSTRUCTION_S(COMP_OPCODE, 14, 9+COMP_EXTEND); // 2^14B hash table size

  // Set history size
  printf("Fn 8: Set history size (max offset)\n");
  ROCC_INSTRUCTION_S(COMP_OPCODE, 64L<<10, 8+COMP_EXTEND); // 64KB history size

  // Latency injection
  printf("Fn 10: Latency injection\n");
  bool has_intermediate_cache = false;
  ROCC_INSTRUCTION_SS(COMP_OPCODE, 0L, has_intermediate_cache, 10+COMP_EXTEND); //0 cycle latency

//-----------------------------------------------------------------

  // Compress begins
  // src info
  printf("Fn 1: ip, isize\n");
  ROCC_INSTRUCTION_SS(COMP_OPCODE, benchmark_uncompressed_data_0, benchmark_uncompressed_data_0_len, 1+COMP_EXTEND);
  // literal buffer info
  printf("Fn 2: litbuf, litbuffsize\n");
  ROCC_INSTRUCTION_SS(COMP_OPCODE, litbuf, buffersize, 2+COMP_EXTEND);
  // sequence buffer info
  printf("Fn 3: seqbuf, seqbuffsize\n");
  ROCC_INSTRUCTION_SS(COMP_OPCODE, seqbuf, buffersize, 3+COMP_EXTEND);
  // dest info
  printf("Fn 4: op, success flag\n");
  bool cmpflag;
  ROCC_INSTRUCTION_SS(COMP_OPCODE, result_area, cmpflag, 4+COMP_EXTEND);
  // compression level
  printf("Fn 5: comp level\n");
  int clevel = 3;
  ROCC_INSTRUCTION_S(COMP_OPCODE, clevel, 5+COMP_EXTEND);

  // completion check
  uint64_t retval;
  ROCC_INSTRUCTION_D(COMP_OPCODE, retval, 11+COMP_EXTEND);
  // asm volatile("fence");
  // while(!*(completion_flag)){asm volatile("fence");}
  // return *completion_flag
  printf("End of rocc instructions\n");

  // Check output
  printf("Input size: %" PRIu32 ", Output size: %" PRId64 "\n", benchmark_uncompressed_data_0_len, retval);
  printf("Check output\n");
  uint64_t * benchmark_compressed_data_by8 = (uint64_t *) benchmark_compressed_data_0;
  uint64_t * result_area_by8 = (uint64_t *) result_area;
  size_t bench_num_words = benchmark_compressed_data_0_len / 8;
  size_t tail_start = bench_num_words * 8;
  bool fail = false;
  bool first_fail = true;
  int benchno = 0; int sram_size = 65536; unsigned char bench_name[] = "default";

  for (size_t i = 0; i < bench_num_words; i++) {
    if (benchmark_compressed_data_by8[i] != result_area_by8[i]) {
      printf("FAIL: mismatch on word %" PRIu64 ": expected: 0x%016" PRIx64 ", got: 0x%016" PRIx64 "\n", i, (uint64_t)((uint64_t)benchmark_compressed_data_by8[i]), (uint64_t)((uint64_t)result_area_by8[i]));
      fail = true;
      if (first_fail) {
        printf("FAIL ON BENCHMARK! N: %" PRId32 ", name: %s, with histsram: %" PRId32 "\n", benchno, bench_name, sram_size);
        first_fail = false;
        break;
      }
    }
    if ((((i*8) % 1000) == 0) && !fail) {
      printf("Good after %" PRIu64 " bytes\n", i*8);
    }
  }
  for (size_t i = tail_start; i < benchmark_compressed_data_0_len; i++) {
    if (fail){
      break;
    }
    if (benchmark_compressed_data_0[i] != result_area[i]) {
      fail = true;
      if(first_fail){
        printf("FAIL ON BENCHMARK! N: %d, name: %s, with histsram: %" PRId32 "\n", benchno, bench_name, sram_size);
        first_fail = false;
      }
    }
  }
  assert(fail == false);
  printf("compress success!\n");
  for (size_t i = 0; i < 1; i++) {
    printf("word %" PRIu64 ": expected: 0x%016" PRIx64 ", got: 0x%016" PRIx64 "\n", i, (uint64_t)((uint64_t)benchmark_compressed_data_by8[i]), (uint64_t)((uint64_t)result_area_by8[i]));
  }
}
