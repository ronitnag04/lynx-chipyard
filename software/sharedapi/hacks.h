#ifndef HACKS_H
#define HACKS_H

#include <stdint.h>
#include <stddef.h>

void ResetSerializedData(void);

void FillPreSerializedData(size_t id, uint8_t* srcbuffer, size_t len, uint64_t time_ns);

void UpdatePreSerializedData(size_t id, uint64_t time_ns);

size_t GetPreSerializedLen(size_t id);

void GetPreSerializedDataTime(size_t id, uint8_t* dstbuffer, size_t* time_ns);

size_t GetPreSerializedTime(size_t id);

size_t GetLargestId(void);

void Hacks_InitPreCompressedData(size_t id, uint8_t* srcbuffer, size_t len, uint64_t time_ns, uint64_t time_acc_ns, uint64_t time_c, uint64_t time_acc_c);
size_t Hacks_GetPreCompressedCPUTimeNs(size_t id);
void Hacks_UpdatePreCompressedCPUTimeNs(size_t id, uint64_t time_ns);
size_t Hacks_GetPreCompressedACCTimeNs(size_t id);
void Hacks_UpdatePreCompressedACCTimeNs(size_t id, uint64_t time_ns);
size_t Hacks_GetPreCompressedCPUTimeC(size_t id);
void Hacks_UpdatePreCompressedCPUTimeC(size_t id, uint64_t time_c);
size_t Hacks_GetPreCompressedACCTimeC(size_t id);
void Hacks_UpdatePreCompressedACCTimeC(size_t id, uint64_t time_c);
void Hacks_GetCompressInput(size_t id, uint8_t** buff, size_t* len);

void Hacks_PutPreCompressedCPUTimeNs(size_t id, size_t time_ns);
void Hacks_PutPreCompressedACCTimeNs(size_t id, size_t time_ns);
size_t Hacks_GetPreCompressedCPUTimeNsActual(size_t id);
size_t Hacks_GetPreCompressedACCTimeNsActual(size_t id);

#endif
