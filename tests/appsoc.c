#include <stdio.h>
#include <riscv-pk/encoding.h>
#include "marchid.h"

int main(void) {
  printf("Printing from App. SoC\n");

  // wait N cycles (for the other program to load / write to an address)
  volatile uint64_t* myDramAddr = (volatile uint64_t*)0x90000000UL;
  myDramAddr -= 4;
  *myDramAddr = 0x4b1eb4b1;

  volatile uint64_t* smartNICaddr = (volatile uint64_t*)0xb0000000UL;
  smartNICaddr -= 4;
  printf("Polling %p\n", smartNICaddr);
  while (*smartNICaddr != 0xdeadbeef) {}

  printf("Able to see other SoC up\n");

  return 0;
}
