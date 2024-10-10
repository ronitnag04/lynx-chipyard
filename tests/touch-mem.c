#include <stdio.h>
#include <riscv-pk/encoding.h>
#include "marchid.h"
#include <stdint.h>

#define PER_SPAD_B_SZ (256 << 10)

int main(void) {
  uint64_t* ptrs[] = {
    0x30000000L,
    0x31000000L,
    0x40000000L,
    0x41000000L,
    0x50000000L,
    0x51000000L,
    0x60000000L,
    0x70000000L,
  };

  for (int i = 0; i < 8; ++i) {
    // touch beginning
    uint64_t* p = ptrs[i];
    printf("SA->0x%lx\n", p);
    *p = 0xDEADBEEFL;

    printf("R<-0x%lx\n", *p);

    // touch end
    p = ptrs[i] + (PER_SPAD_B_SZ / 8) - 1;
    //printf("SA->0x%lx (0x%lx - 1W)\n", p, PER_SPAD_B_SZ);
    printf("SA->0x%lx\n", p);
    *p = 0xDEADBEEFL;

    printf("R<-0x%lx\n", *p);
  }

  return 0;
}
