#ifndef HACKS_H
#define HACKS_H

#include <stdint.h>
#include <stddef.h>

void ResetSerializedData(void);

void FillPreSerializedData(size_t id, uint8_t* srcbuffer, size_t len, uint64_t time_ns);

void UpdatePreSerializedData(size_t id, uint64_t time_ns);

size_t GetPreSerializedLen(size_t id);

void GetPreSerializedDataTime(size_t id, uint8_t* dstbuffer, size_t* time_ns);

#endif
