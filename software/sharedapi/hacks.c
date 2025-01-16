#include "hacks.h"
#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

typedef struct {
  size_t id; // unique id (i.e. hash of buff)
  uint8_t* buff; // pre-serialized data
  size_t len; // len given by CPU serialization
  uint64_t time_ns; // time to serialize on the CPU
} entry_t;

size_t num_entries;
entry_t entries[1000];

void ResetSerializedData(void) {
  num_entries = 0;
}

void FillPreSerializedData(size_t id, uint8_t* srcbuffer, size_t len, uint64_t time_ns) {
  //printf("FillPreSerializedData: In: uniqid:%lu, len:%d, timens:%lu\n", id, len, time_ns);

  for (size_t i = 0; i < num_entries; ++i) {
    entry_t* entry = &entries[i];
    if (id == entry->id) {
      return; // keep old entry
    }
  }

  assert(num_entries < 1000);

  entry_t* entry = &entries[num_entries];
  entry->id = id;
  entry->buff = malloc(len);
  if (entry->buff == NULL) {
    fprintf(stderr, "ERR: unable to malloc %d sz\n", len);
  }
  memcpy(entry->buff, srcbuffer, len);
  entry->len = len;
  entry->time_ns = time_ns;

  ++num_entries;

  fprintf(stderr, "Adding pre-serialized data: eid:%d, uniqid:%lu, len:%d, timens:%lu\n", num_entries-1, entry->id, len, time_ns);
  // for (size_t i = 0; i < len; ++i) {
  //   printf("%02x", srcbuffer[i]);
  // }
  // printf("\n");
}

// averages things out
void UpdatePreSerializedData(size_t id, uint64_t time_ns) {
  for (size_t i = 0; i < num_entries; ++i) {
    entry_t* entry = &entries[i];
    if (id == entry->id) {
      entry->time_ns = (entry->time_ns + time_ns) / 2;
      //printf("Updating pre-serialized time: uniqid:%lu, (in)timens:%lu (out)timens:%lu\n", entry->id, time_ns, entry->time_ns);
      return;
    }
  }
}

size_t GetPreSerializedLen(size_t id) {
  //printf("Grabbing %lu (len)\n", id);
  for (size_t i = 0; i < num_entries; ++i) {
    entry_t* entry = &entries[i];
    if (id == entry->id) {
      return entry->len;
    }
  }
  assert(false);
}

void GetPreSerializedDataTime(size_t id, uint8_t* dstbuffer, size_t* time_ns) {
  //printf("Grabbing %lu (data)\n", id);
  for (size_t i = 0; i < num_entries; ++i) {
    entry_t* entry = &entries[i];
    if (id == entry->id) {
      memcpy(dstbuffer, entry->buff, entry->len);
      *time_ns = entry->time_ns;
      // for (size_t i = 0; i < entry->len; ++i) {
      //   printf("(%02x:%02x)", dstbuffer[i], entry->buff[i]);
      // }
      // printf("\n");
      return;
    }
  }
  assert(false);
}
