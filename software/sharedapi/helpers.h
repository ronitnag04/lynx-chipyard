#ifndef HELPERS_H
#define HELPERS_H

#include <stddef.h>

void ForcePagedIn(void* region, size_t size);

size_t MultipleOf(size_t in, size_t multiple_of);

void* AllocAligned(size_t size, size_t* alloc_size);

#endif
