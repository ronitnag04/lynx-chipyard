#ifndef OPENSSL_HEADER_CRYPTO_ROCC_H
#define OPENSSL_HEADER_CRYPTO_ROCC_H

#if !defined(__x86_64__)

#if defined(USE_DECRYPT_ACC) || defined(USE_ENCRYPT_ACC)

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define AES_OPCODE 1

uint8_t * AESCBCAccelSetup(size_t write_region_size);

void AESCBCAccelNonblocking(bool encrypt,
                const uint8_t* data,
                size_t data_length,
                uint64_t key0,
                uint64_t key1,
                uint64_t key2,
                uint64_t key3,
                uint64_t iv0,
                uint64_t iv1,
                uint8_t* result,
                uint64_t* success_flag);

uint64_t AESCBCAccel(bool encrypt,
                const uint8_t* data,
                size_t data_length,
                uint64_t key0,
                uint64_t key1,
                uint64_t key2,
                uint64_t key3,
                uint64_t iv0,
                uint64_t iv1,
                uint8_t* result);

volatile uint64_t AESCBCBlockOnCompletion(volatile uint64_t * completion_flag);

#endif

#endif

#endif  // OPENSSL_HEADER_CRYPTO_ROCC_H
