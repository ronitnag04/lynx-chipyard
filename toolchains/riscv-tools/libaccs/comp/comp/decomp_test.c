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

#define MEMCPY_OPCODE 0 //It's actually 4
#define DECOMP_OPCODE 0

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

  // Set result area
  printf("Fn 0: Fence\n");
  ROCC_INSTRUCTION_I_I_I(0, 0, 0, 0, 0);
  printf("Fn 7: Set hist size\n");
  ROCC_INSTRUCTION_I_R_I(0, 0, 65536, 0, 7); //64K hist size
  printf("Write region init\n");
  unsigned char* write_region = MemSetup(benchmark_uncompressed_data_0_len);

  // Set workspace area
  printf("Workspace region init\n");
  unsigned char* workspace = MemSetup(benchmark_uncompressed_data_0_len);

  // Latency injection
  printf("Fn 2: Latency injection\n");
  ROCC_INSTRUCTION_I_R_I(0, 0, 0, 0, 2); //0 cycle latency

  // Set history size
  printf("Fn 7: Set hist size\n");
  ROCC_INSTRUCTION_I_R_I(0, 0, 65536, 0, 7); //64K hist size

  // Algorithm
  printf("Fn 1: Algorithm\n");
  ROCC_INSTRUCTION_I_R_I(0, 0, 0, 0, 1); //Algorithm=Zstd(0) or Snappy(1)

  // ip, isize
  printf("Fn 3: ip, isize\n");
  ROCC_INSTRUCTION_I_R_R(0, 0, benchmark_compressed_data_0, benchmark_compressed_data_0_len, 3);

  // workspace
  printf("Fn 4: wksp\n");
  ROCC_INSTRUCTION_I_R_I(0, 0, workspace, 0, 4);

  // op, cmpflag
  printf("Fn 5: op, cmpflag\n");
  bool cmpflag;
  ROCC_INSTRUCTION_I_R_R(0, 0, write_region, cmpflag, 5);

  // Check completion
  printf("Fn 6: Check completion\n");
  uint64_t retval;
  ROCC_INSTRUCTION_R_R_I(0, retval, 0, 0, 6);
  printf("End of rocc instructions\n");

  // Check output
  printf("Check output\n");
  uint64_t * benchmark_uncompressed_data_by8 = (uint64_t *) benchmark_uncompressed_data_0;
  uint64_t * result_area_by8 = (uint64_t *) write_region;
  size_t bench_num_words = benchmark_uncompressed_data_0_len / 8;
  size_t tail_start = bench_num_words * 8;
  bool fail = false;
  bool first_fail = true;
  int benchno = 0; int sram_size = 65536; unsigned char bench_name[] = "default";

  for (size_t i = 0; i < bench_num_words; i++) {
    if (benchmark_uncompressed_data_by8[i] != result_area_by8[i]) {
      printf("FAIL: mismatch on word %" PRIu64 ": expected: 0x%016" PRIx64 ", got: 0x%016" PRIx64 "\n", i, (uint64_t)((uint64_t)benchmark_uncompressed_data_by8[i]), (uint64_t)((uint64_t)result_area_by8[i]));
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
  for (size_t i = tail_start; i < benchmark_uncompressed_data_0_len; i++) {
    if (fail){
      break;
    }
    if (benchmark_uncompressed_data_0[i] != write_region[i]) {
      fail = true;
      if(first_fail){
        printf("FAIL ON BENCHMARK! N: %" PRId32 ", name: %s, with histsram: %" PRId32 "\n", benchno, bench_name, sram_size);
        first_fail = false;
      }
    }
  }
  assert(fail == false);
  printf("decompress success!\n");
  for (size_t i = 0; i < 1; i++) {
    printf("word %" PRIu64 ": expected: 0x%016" PRIx64 ", got: 0x%016" PRIx64 "\n", i, (uint64_t)((uint64_t)benchmark_uncompressed_data_by8[i]), (uint64_t)((uint64_t)result_area_by8[i]));
  }
}
/*
// For decompressor
  ROCC_INSTRUCTION_I_I_I(DECOMP_OPCODE, 0, 0, 0, 0); //FENCE
  //Set memory region
  ROCC_INSTRUCTION_I_R_I(DECOMP_OPCODE, 0, hist_sram_size, 0, 7); //SET ONCHIP HIST
  ROCC_INSTRUCTION_I_R_R(DECOMP_OPCODE, 0, benchmark_compressed_data_0, benchmark_compressed_data_0_len, 1); //ip, isize
  bool cmpflag;
  ROCC_INSTRUCTION_I_R_R(DECOMP_OPCODE, 0,
*/
