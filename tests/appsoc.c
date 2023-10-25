#include <stdio.h>
#include <riscv-pk/encoding.h>
#include "marchid.h"

#define SMARTNIC_DRAM_BASE (0xA0000000UL)
#define SMARTNIC_DRAM_SZ (0x10000000UL)
#define APP_DRAM_BASE (0x80000000UL)
#define APP_DRAM_SZ (0x10000000UL)

#define HANDSHAKE_0 (0xDEADBEEFUL) // written to smartnic memory
#define HANDSHAKE_1 (0x4B1EB4B1UL) // written to app memory

int main(void) {
  printf("START: AppSoC Test\n");

  volatile uint64_t* aAddr = ((volatile uint64_t*)(APP_DRAM_BASE + APP_DRAM_SZ) - 1);
  *aAddr = HANDSHAKE_1;

  printf("INFO: Wrote handshake 1\n");

  volatile uint64_t* snAddr = ((volatile uint64_t*)(SMARTNIC_DRAM_BASE + SMARTNIC_DRAM_SZ) - 1);
  do {
    printf("Polling %p...\n", snAddr);
  } while (*snAddr != HANDSHAKE_0);

  printf("PASS: Saw SmartNICSoC\n");

  return 0;
}
