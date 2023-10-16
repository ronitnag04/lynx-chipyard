#include <stdio.h>
#include <riscv-pk/encoding.h>
#include "marchid.h"
#include "kprintf.h"
#include "mmio.h"

int main(void) {
  // enable uart
  REG32(uart, UART_REG_TXCTRL) = UART_TXEN;
  kputs("Starting smartNIC");

  volatile uint64_t* smartNICaddr = (volatile uint64_t*)0xb0000000UL;
  smartNICaddr -= 4;
  *smartNICaddr = 0xdeadbeef;

  kputs("Done writing address");

  return 0;
}
