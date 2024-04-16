#include <stdio.h>
#include <stdint.h>
#include <riscv-pk/encoding.h>
#include "marchid.h"
#include "kprintf.h"
#include "mmio.h"

#define SMARTNIC_DRAM_BASE (0xA0000000UL)
#define SMARTNIC_DRAM_SZ (0x10000000UL)
#define APP_DRAM_BASE (0x80000000UL)
#define APP_DRAM_SZ (0x10000000UL)

#define HANDSHAKE_0 (0xDEADBEEFUL) // written to smartnic memory
#define HANDSHAKE_1 (0x4B1EB4B1UL) // written to app memory

// disabled since UART takes much longer to output (faster baudrate doesn't work)
// causing interrupts that take forever to resolve
//#define ENABLE_UART

int main(void) {
#ifdef ENABLE_UART
  // enable uart
  REG32(uart, UART_REG_TXCTRL) = UART_TXEN;
  kputs("START: SmartNICSoC Test\n");
#endif

  volatile uint64_t* aAddr = ((volatile uint64_t*)(APP_DRAM_BASE + APP_DRAM_SZ) - 1);
  do {
#ifdef ENABLE_UART
    kputs("Polling...\n");
#endif
  } while (*aAddr != HANDSHAKE_1);

#ifdef ENABLE_UART
  kputs("PASS: Saw AppSoC\n");
#endif

  volatile uint64_t* snAddr = ((volatile uint64_t*)(SMARTNIC_DRAM_BASE + SMARTNIC_DRAM_SZ) - 1);
  *snAddr = HANDSHAKE_0;

#ifdef ENABLE_UART
  kputs("INFO: Wrote handshake 0\n");
#endif

  while (1) {}

  // never reach this
  return 0;
}
