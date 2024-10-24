#ifndef HELPERS_H
#define HELPERS_H

#include <stddef.h>
#include <stdbool.h>

#define __read_csr(reg) ({ unsigned long __tmp; \
  __asm__ __volatile__ ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })
#define rdcycle() __read_csr(cycle)

void ForcePagedIn(void* region, size_t size);
void ForcePagedInOverride(void* region, size_t size, bool override_no_mlock);
void ForcePagedOut(void* region, size_t size);
void ForcePagedOutOverride(void* region, size_t size, bool override_no_mlock);

size_t MultipleOf(size_t in, size_t multiple_of);

void* AllocAligned(size_t size, size_t* alloc_size);

#endif
