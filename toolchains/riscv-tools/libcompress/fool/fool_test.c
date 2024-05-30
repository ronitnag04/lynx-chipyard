// The following is a RISC-V program to test the functionality of the
// dummy RoCC accelerator.
// Compile with riscv64-unknown-elf-gcc fool_rocc_test.c
// Run with spike --extension=fool pk a.out

#include "rocc.h"
#include "encoding.h"
#include <assert.h>
#include <stdio.h>
#include <stdint.h>

int main() {
  uint64_t x = 123, y = 456, z = 0;
  // load x into accumulator 2 (funct=0)
  // asm volatile ("custom0 x0, %0, 2, 0" : : "r"(x));
  ROCC_INSTRUCTION_I_R_I(0, 0, x, 2, 0);
  
  // read it back into z (funct=1) to verify it
  // asm volatile ("custom0 %0, x0, 2, 1" : "=r"(z));
  ROCC_INSTRUCTION_R_R_I(0, z, 0, 2, 1); 
  assert(z == x);
  // accumulate 456 into it (funct=3)
  // asm volatile ("custom0 x0, %0, 2, 3" : : "r"(y));
  ROCC_INSTRUCTION_I_R_I(0, 0, y, 2, 3);
  // verify it
  //asm volatile ("custom0 %0, x0, 2, 1" : "=r"(z));
  ROCC_INSTRUCTION_R_R_I(0, z, 0, 2, 1);
  assert(z == x+y);
  // do it all again, but initialize acc2 via memory this time (funct=2)
  // asm volatile ("custom0 x0, %0, 2, 2" : : "r"(&x));
  ROCC_INSTRUCTION_I_R_I(0, 0, &x, 2, 2);
  // asm volatile ("custom0 x0, %0, 2, 3" : : "r"(y));
  ROCC_INSTRUCTION_I_R_I(0, 0, y, 2, 3);
  // asm volatile ("custom0 %0, x0, 2, 1" : "=r"(z));
  ROCC_INSTRUCTION_R_R_I(0, z, 0, 2, 1);
  assert(z == x+y);
  printf("accel 0 success!\n");
  // For accel 1 (dummy adder)

  z = 0;
  ROCC_INSTRUCTION_I_I_I(1, 0, 0, 0, 0);
  ROCC_INSTRUCTION_I_R_R(1, 0, x, y, 1);
  ROCC_INSTRUCTION_R_I_I(1, z, 0, 0, 2);
  assert(z == x+y);
  printf("accel 1 success!\n");

}
