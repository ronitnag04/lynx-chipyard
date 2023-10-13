#include <stdio.h>
#include <riscv-pk/encoding.h>
#include "marchid.h"

int main(void) {
  uint64_t marchid = read_csr(marchid);
  const char* march = get_march(marchid);
  printf("Hello world from core 0, a %s\n", march);

  printf("Attempting to read from smartNICaddr\n");

  uint64_t* smartNICaddr = 0xa0000000UL;
  *smartNICaddr = 0xdeadbeef;

  printf("Wrote to smartNIC address\n");

  uint64_t tmp = -1;
  tmp = *smartNICaddr;

  printf("Read from smartNIC address = %lu\n", tmp);

  return 0;
}
