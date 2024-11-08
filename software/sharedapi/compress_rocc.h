#ifndef COMPRESS_ROCC_H
#define COMPRESS_ROCC_H

#if !defined(__x86_64__)

#if defined(USE_COMPRESS_ACC) || defined(USE_DECOMPRESS_ACC)

#include <inttypes.h>
#include <stddef.h>

#define ZSTD_DECOMP_OPCODE 0
#define ZSTD_COMP_OPCODE 1
size_t GetZStdDecompressSize(uint8_t* compressed_data, size_t len);
size_t ZStdCompress(volatile uint8_t* litbuf, size_t litbuf_sz, volatile uint8_t* seqbuf, size_t seqbuf_sz, uint8_t* src, size_t src_sz, uint8_t* dest);
size_t ZStdDecompress(volatile uint8_t* workspace, uint8_t* src, size_t src_sz, uint8_t* dest);

#define SNAPPY_DECOMP_OPCODE 0
#define SNAPPY_COMP_OPCODE 1
size_t GetSnappyDecompressSize(uint8_t* compressed_data, size_t len);
size_t SnappyCompress(uint8_t* src, size_t src_sz, uint8_t* dest);
size_t SnappyDecompress(uint8_t* src, size_t src_sz, uint8_t* dest);

#endif

#endif

#endif // COMPRESS_ROCC_H
