#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>

#include "accellib.h"
#include "encoding.h"

#define AES_BLOCK_BITS (128)
#define AES_BLOCK_BYTES (AES_BLOCK_BITS / 8)
#define DATA_LEN_BYTES (2 * AES_BLOCK_BYTES)

int main() {

  uint64_t data_len = DATA_LEN_BYTES; // 1 256 xaction
  //uint64_t data_len = (data_len / 128) * 128; // round to 128
  unsigned char data[DATA_LEN_BYTES];
  for (size_t i = 0; i < data_len; ++i) {
    data[i] = 0;
  }
  uint64_t key[4];
  for (size_t i = 0; i < 4; ++i) {
    key[i] = 0;
  }

  for (size_t i = 0; i < DATA_LEN_BYTES / AES_BLOCK_BYTES; i++) {
    uint64_t* data64 = (uint64_t*)data;
    printf("Block[%d]: 0x%08x%08x\n", i, *(data64 + (2*i) + 1), *(data64 + (2*i)));
  }

  printf(">> Encrypt start: L:%lu\n", data_len);

  uint8_t* ciphertext_area = Aes256AccelSetup(data_len); // fence, write zero

  printf("src start addr: 0x%08" PRIx64 "\n", (uint64_t)data);
  printf("dest start addr: 0x%08" PRIx64 "\n", (uint64_t)ciphertext_area);

  uint64_t t1 = rdcycle();

  // encrypt
  Aes256Accel(true,
              data,
              data_len,
              key[0],
              key[1],
              key[2],
              key[3],
              ciphertext_area);
  uint64_t t2 = rdcycle();

  printf("Start cycle: %" PRIu64 ", End cycle: %" PRIu64 ", Took: %" PRIu64 "\n",
          t1, t2, t2 - t1);

  for (size_t i = 0; i < DATA_LEN_BYTES / AES_BLOCK_BYTES; i++) {
    uint64_t* data64 = (uint64_t*)ciphertext_area;
    printf("Block[%d]: 0x%08x%08x\n", i, *(data64 + (2*i) + 1), *(data64 + (2*i)));
  }


  // decryption start area
  printf(">> Decrypt start: L:%lu\n", data_len);

  uint8_t* plaintext_area = Aes256AccelSetup(data_len); // fence, write zero

  printf("src start addr: 0x%08" PRIx64 "\n", (uint64_t)ciphertext_area);
  printf("dest start addr: 0x%08" PRIx64 "\n", (uint64_t)plaintext_area);

  t1 = rdcycle();

  // decrypt
  Aes256Accel(false,
              ciphertext_area,
              data_len,
              key[0],
              key[1],
              key[2],
              key[3],
              plaintext_area);
  t2 = rdcycle();

  printf("Start cycle: %" PRIu64 ", End cycle: %" PRIu64 ", Took: %" PRIu64 "\n",
          t1, t2, t2 - t1);

  for (size_t i = 0; i < DATA_LEN_BYTES / AES_BLOCK_BYTES; i++) {
    uint64_t* data64 = (uint64_t*)plaintext_area;
    printf("Block[%d]: 0x%08x%08x\n", i, *(data64 + (2*i) + 1), *(data64 + (2*i)));
  }

  printf("Checking encrypt/decrypt data correctness:\n");
  bool fail = false;
  for (size_t i = 0; i < data_len; i++) {
    if (data[i] != plaintext_area[i]) {
      printf("idx %" PRIu64 ": expected: %x got: %x\n",
          i, data[i], plaintext_area[i]);
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
