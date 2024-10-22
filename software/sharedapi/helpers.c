#include <malloc.h>
#include <stdint.h>
#include <assert.h>
#include "helpers.h"

#define PAGESIZE_BYTES 4096
#define MAX_BUS_WIDTH 256

#define accprintf(...) (0)

void ForcePagedIn(void* region, size_t size) {
#if defined(__linux) && defined(USE_MLOCK)
    if (mlock(region, size) != 0) {
      accprintf("E: mlock failed: unable to pin pages\n");
    }
#else
  for (size_t i = 0; i < size; i += PAGESIZE_BYTES) {
    ((char*)region)[i] = 0;
  }
#endif
}

size_t MultipleOf(size_t in, size_t multiple_of) {
  assert(multiple_of >= 0);
  return ((in + multiple_of - 1) / multiple_of) * multiple_of;
}

void* AllocAligned(size_t size, size_t* alloc_size) {
  size_t mult_size = MultipleOf(size, MAX_BUS_WIDTH); // round up to nearest multiple of MAX_BUS_WIDTH (buswidth) (also 64 since accelerator deals with 64 only)
  void* region = memalign(PAGESIZE_BYTES, mult_size);
  if (region == NULL) {
    accprintf("E: malloc failed: nullptr returned\n");
  }
  *alloc_size = mult_size;
  return region;
}
