#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>

#include "accellib.h"
#include "encoding.h"
#include "data.h"

int main() {
  uint64_t mod_data_len = 2 * (128/8); // 1 256 xact
  // (data_len / 128) * 128,

  printf("Starting encryption. %lu\n", mod_data_len);

  uint8_t* result_area = Aes256AccelSetup(data_len); // fence, write zero

  printf("src start addr: 0x%016" PRIx64 "\n", (uint64_t)data);
  printf("dest start addr: 0x%016" PRIx64 "\n", (uint64_t)result_area);

  uint64_t t1 = rdcycle();

  // encrypt
  Aes256Accel(true,
              data,
              mod_data_len,
              0xAAAAAAAA,
              0xBBBBBBBB,
              0xCCCCCCCC,
              0xDDDDDDDD,
              result_area);
  uint64_t t2 = rdcycle();

  printf("Start cycle: %" PRIu64 ", End cycle: %" PRIu64 ", Took: %" PRIu64 "\n",
          t1, t2, t2 - t1);

  // decryption start area
  printf("Starting decryption. %lu\n", mod_data_len);

  uint8_t* result_area2 = Aes256AccelSetup(data_len); // fence, write zero

  printf("src start addr: 0x%016" PRIx64 "\n", (uint64_t)result_area);
  printf("dest start addr: 0x%016" PRIx64 "\n", (uint64_t)result_area2);

  t1 = rdcycle();

  // decrypt
  Aes256Accel(false,
              result_area,
              mod_data_len,
              0xAAAAAAAA,
              0xBBBBBBBB,
              0xCCCCCCCC,
              0xDDDDDDDD,
              result_area2);
  t2 = rdcycle();

  printf("Start cycle: %" PRIu64 ", End cycle: %" PRIu64 ", Took: %" PRIu64 "\n",
          t1, t2, t2 - t1);

  printf("Checking encrypt/decrypt data correctness:\n");
  bool fail = false;
  for (size_t i = 0; i < data_len; i++) {
    if (data[i] != result_area2[i]) {
      printf("idx %" PRIu64 ": expected: %x got: %x\n",
          i, data[i], result_area2[i]);
      fail = true;
      break;
    }
  }

  if (fail) {
      printf("TEST FAILED!\n");
      exit(1);
  } else {
      printf("TEST PASSED!\n");
  }

  return 0;
}
