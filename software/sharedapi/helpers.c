#include <malloc.h>
#include <stdint.h>
#include <assert.h>
#include <sys/mman.h>
#include "helpers.h"

#define PAGESIZE_BYTES 4096
#define MAX_BUS_WIDTH 256

#define accprintf(...) (0)

void ForcePagedIn(void* region, size_t size) {
  ForcePagedInOverride(region, size, false);
}

// note: mlock versions of these functions take a long time to run
void ForcePagedInOverride(void* region, size_t size, bool override_no_mlock) {
  bool can_use_mlock = false;
#if defined(__linux) && defined(USE_MLOCK)
  can_use_mlock = true;
#endif
  if (can_use_mlock && !override_no_mlock) {
    if (mlock(region, size) != 0) {
      accprintf("E: mlock failed: unable to pin pages\n");
    }
  } else {
    for (size_t i = 0; i < size; i += PAGESIZE_BYTES) {
      ((char*)region)[i] = 0;
    }
  }
}

void ForcePagedOut(void* region, size_t size) {
  ForcePagedOutOverride(region, size, false);
}

void ForcePagedOutOverride(void* region, size_t size, bool override_no_mlock) {
  bool can_use_mlock = false;
#if defined(__linux) && defined(USE_MLOCK)
  can_use_mlock = true;
#endif
  if (can_use_mlock && !override_no_mlock) {
    if (munlock(region, size) != 0) {
      accprintf("E: munlock failed: unable to free pages\n");
    }
  }
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
