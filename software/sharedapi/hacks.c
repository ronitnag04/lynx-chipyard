#include "hacks.h"
#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

typedef struct {
  bool filled;
  uint8_t* buff; // pre-serialized data
  size_t len; // len given by CPU serialization
  uint64_t time_ns; // time to serialize on the CPU
  uint64_t time_acc_ns; // time to serialize on the ACC
  uint64_t time_c; // time to serialize on the CPU
  uint64_t time_acc_c; // time to serialize on the ACC
} entry_t;

entry_t entries[1000];
entry_t entries_c[1000];

void ResetSerializedData(void) {
}

// use the id given to index into the array
void FillPreSerializedData(size_t id, uint8_t* srcbuffer, size_t len, uint64_t time_ns) {
  //printf("FillPreSerializedData: In: uniqid:%lu, len:%d, timens:%lu\n", id, len, time_ns);

  assert(id < 1000);

  entry_t* entry = &entries[id];
  if (entry->filled) {
    entry->time_ns = (entry->time_ns + time_ns) / 2;
    assert(len == entry->len);
    fprintf(stderr, "Adding pre-serialized data: uniqid:%lu Avg'ing: intimens:%lu outtimens:%lu\n", id, time_ns, entry->time_ns);
    return; // keep old entry
  }

  entry->filled = true;
  entry->buff = malloc(len);
  if (entry->buff == NULL) {
    fprintf(stderr, "ERR: unable to malloc %d sz\n", len);
  }
  memcpy(entry->buff, srcbuffer, len);
  entry->len = len;
  entry->time_ns = time_ns;

  fprintf(stderr, "Adding pre-serialized data: uniqid:%lu, len:%d, timens:%lu\n", id, len, time_ns);
  // for (size_t i = 0; i < len; ++i) {
  //   printf("%02x", srcbuffer[i]);
  // }
  // printf("\n");
}

// averages things out
void UpdatePreSerializedData(size_t id, uint64_t time_ns) {
  entry_t* entry = &entries[id];
  assert(entry->filled);
  entry->time_ns = (entry->time_ns + time_ns) / 2;
  //fprintf(stderr, "Updating pre-serialized time: uniqid:%lu, (in)timens:%lu (out)timens:%lu\n", id, time_ns, entry->time_ns);
}

size_t GetLargestId(void) {
  size_t max = 0;
  for (size_t i = 0; i < 1000; ++i) {
    entry_t* entry = &entries[1000 - i];
    if (entry->filled) {
      return 1000 - i + 1;
    }
  }
  assert(false);
}

size_t GetPreSerializedLen(size_t id) {
  //printf("Grabbing %lu (len)\n", id);
  return entries[id].len;
}

void GetPreSerializedDataTime(size_t id, uint8_t* dstbuffer, size_t* time_ns) {
  //printf("Grabbing %lu (data)\n", id);
  entry_t* entry = &entries[id];
  memcpy(dstbuffer, entry->buff, entry->len);
  *time_ns = entry->time_ns;
  // for (size_t i = 0; i < entry->len; ++i) {
  //   printf("(%02x:%02x)", dstbuffer[i], entry->buff[i]);
  // }
  // printf("\n");
}

size_t GetPreSerializedTime(size_t id) {
  //fprintf(stderr, "Get pre-serialized data: uniqid:%lu, timens:%lu\n", id, entries[id].time_ns);
  return entries[id].time_ns;
}



// use the id given to index into the array
void Hacks_InitPreCompressedData(size_t id, uint8_t* srcbuffer, size_t len, uint64_t time_ns, uint64_t time_acc_ns, uint64_t time_c, uint64_t time_acc_c) {
  //printf("FillPreSerializedData: In: uniqid:%lu, len:%d, timens:%lu\n", id, len, time_ns);

  assert(id < 1000);

  entry_t* entry = &entries_c[id];
  if (entry->filled) {
    return; // keep old entry
  }

  entry->filled = true;
  entry->buff = malloc(len);
  if (entry->buff == NULL) {
    fprintf(stderr, "ERR: unable to malloc %d sz\n", len);
  }
  memcpy(entry->buff, srcbuffer, len);
  entry->len = len;
  entry->time_ns = time_ns;
  entry->time_acc_ns = time_acc_ns;
  entry->time_c = time_c;
  entry->time_acc_c = time_acc_c;

  fprintf(stderr, "Adding pre-serialized data: uniqid:%lu, len:%d, timens:%lu acctimens:%lu timec:%lu acctimec:%lu\n", id, len, time_ns, time_acc_ns, time_c, time_acc_c);
  // for (size_t i = 0; i < len; ++i) {
  //   printf("%02x", srcbuffer[i]);
  // }
  // printf("\n");
}

size_t Hacks_GetPreCompressedCPUTimeNs(size_t id) {
  return entries_c[id].time_ns;
}

size_t Hacks_GetPreCompressedACCTimeNs(size_t id) {
  return entries_c[id].time_acc_ns;
}

size_t Hacks_GetPreCompressedCPUTimeC(size_t id) {
  return entries_c[id].time_c;
}

size_t Hacks_GetPreCompressedACCTimeC(size_t id) {
  return entries_c[id].time_acc_c;
}

void Hacks_UpdatePreCompressedCPUTimeNs(size_t id, uint64_t time_ns) {
  //printf("Attempting update of pre-serialized time: uniqid:%lu, (in)timens:%lu\n", id, time_ns);
  entry_t* entry = &entries_c[id];
  assert(entry->filled);
  entry->time_ns = (entry->time_ns + time_ns) / 2;
  //printf("Updating pre-serialized time: uniqid:%lu, (in)timens:%lu (out)timens:%lu\n", id, time_ns, entry->time_ns);
}

void Hacks_UpdatePreCompressedACCTimeNs(size_t id, uint64_t time_ns) {
  //printf("Attempting update of pre-serialized time: uniqid:%lu, (in)timens:%lu\n", id, time_ns);
  entry_t* entry = &entries_c[id];
  assert(entry->filled);
  entry->time_acc_ns = (entry->time_acc_ns + time_ns) / 2;
  //printf("Updating pre-serialized time: uniqid:%lu, (in)timens:%lu (out)timens:%lu\n", id, time_ns, entry->time_ns);
}

void Hacks_UpdatePreCompressedCPUTimeC(size_t id, uint64_t time_c) {
  //printf("Attempting update of pre-serialized time: uniqid:%lu, (in)timec:%lu\n", id, time_c);
  entry_t* entry = &entries_c[id];
  assert(entry->filled);
  entry->time_c = (entry->time_c + time_c) / 2;
  //printf("Updating pre-serialized time: uniqid:%lu, (in)timec:%lu (out)timec:%lu\n", id, time_c, entry->time_c);
}

void Hacks_UpdatePreCompressedACCTimeC(size_t id, uint64_t time_c) {
  //printf("Attempting update of pre-serialized time: uniqid:%lu, (in)timec:%lu\n", id, time_c);
  entry_t* entry = &entries_c[id];
  assert(entry->filled);
  entry->time_acc_c = (entry->time_acc_c + time_c) / 2;
  //printf("Updating pre-serialized time: uniqid:%lu, (in)timec:%lu (out)timec:%lu\n", id, time_c, entry->time_c);
}
