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

  volatile uint64_t* myDramAddr = (volatile uint64_t*)0x90000000UL;
  myDramAddr -= 4;
  printf("Polling %p\n", myDramAddr);
  while (*smartNICaddr != 0x4b1eb4b1) {}

  kputs("Able to read other addr");

  return 0;
}
