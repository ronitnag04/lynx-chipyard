#if !defined(__x86_64__)

#if defined(USE_DECRYPT_ACC) || defined(USE_ENCRYPT_ACC)

#include <assert.h>
#include <stdint.h>
#include <inttypes.h>

#include "rocc.h"
#include "helpers.h"
#include "crypto_rocc.h"

#define FUNCT_SFENCE 0
#define FUNCT_SRC_INFO 1
#define FUNCT_MODE 4
#define FUNCT_KEY_0 5
#define FUNCT_KEY_1 6
#define FUNCT_IV 7
#define FUNCT_DEST_INFO 2
#define FUNCT_CHECK_COMPLETION 3

#define accprintf(...) (0)

void AESCBCClearAccelTLB(void) {
    ROCC_INSTRUCTION(AES_OPCODE, FUNCT_SFENCE); // should clear the accel TLB
}

// OLD
uint8_t* AESCBCAccelSetup(size_t write_region_size) {
    AESCBCClearAccelTLB();

    // string data allocation
    size_t fixed_alloc_region_size;
    uint8_t* fixed_alloc_region = (uint8_t*)AllocAligned(sizeof(uint8_t) * write_region_size, &fixed_alloc_region_size);
    ForcePagedIn((void*)fixed_alloc_region, fixed_alloc_region_size);
    uint64_t fixed_alloc_region_ptr_as_int = (uint64_t)fixed_alloc_region;
    accprintf("I: FAR: %lld bytes alloc'ed, start at 0x%016llx\n", (uint64_t)fixed_alloc_region_size, fixed_alloc_region_ptr_as_int);

    assert((fixed_alloc_region_ptr_as_int & 0x7) == 0x0);
    return fixed_alloc_region;
}

volatile uint64_t AESCBCBlockOnCompletion(volatile uint64_t * completion_flag) {
    uint64_t retval;
    ROCC_INSTRUCTION_D(AES_OPCODE, retval, FUNCT_CHECK_COMPLETION);
    __asm__ __volatile__ ("fence");

    while (! *(completion_flag)) {
        __asm__ __volatile__ ("fence");
    }
    return *completion_flag;
}

#define FUNCT_SFENCE 0
#define FUNCT_SRC_INFO 1
#define FUNCT_MODE 4
#define FUNCT_KEY_0 5
#define FUNCT_KEY_1 6
#define FUNCT_IV 7
#define FUNCT_DEST_INFO 2
#define FUNCT_CHECK_COMPLETION 3

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
                            uint64_t* success_flag) {
    assert (data_length % 16 == 0 && "Data length must be divisible by block size of 128b (16B)");
    ROCC_INSTRUCTION_SS(AES_OPCODE,
                        (uint64_t)key0,
                        (uint64_t)key1,
                        FUNCT_KEY_0);

    ROCC_INSTRUCTION_SS(AES_OPCODE,
                        (uint64_t)key2,
                        (uint64_t)key3,
                        FUNCT_KEY_1);

    ROCC_INSTRUCTION_SS(AES_OPCODE,
                        (uint64_t)iv0,
                        (uint64_t)iv1,
                        FUNCT_IV);

    ROCC_INSTRUCTION_S(AES_OPCODE,
                        (uint64_t)encrypt,
                        FUNCT_MODE);

    // this triggers the encrypt/decryption
    ROCC_INSTRUCTION_SS(AES_OPCODE,
                        (uint64_t)data,
                        (uint64_t)data_length,
                        FUNCT_SRC_INFO);

    ROCC_INSTRUCTION_SS(AES_OPCODE,
                        (uint64_t)result,
                        (uint64_t)success_flag,
                        FUNCT_DEST_INFO);
}

uint64_t AESCBCAccel(bool encrypt,
                const uint8_t* data,
                size_t data_length,
                uint64_t key0,
                uint64_t key1,
                uint64_t key2,
                uint64_t key3,
                uint64_t iv0,
                uint64_t iv1,
                uint8_t* result) {
    uint64_t completion_flag = 0;

    AESCBCAccelNonblocking(encrypt,
                            data,
                            data_length,
                            key0,
                            key1,
                            key2,
                            key3,
                            iv0,
                            iv1,
                            result,
                            &completion_flag);
    return AESCBCBlockOnCompletion(&completion_flag);
}

#endif

#endif
