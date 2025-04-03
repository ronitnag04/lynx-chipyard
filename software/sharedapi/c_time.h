#ifndef C_TIME_H
#define C_TIME_H

static inline uint64_t get_cur_ns_raw(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
  return (1e9 * ts.tv_sec) + ts.tv_nsec;
}

static inline uint64_t get_cur_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_BOOTTIME, &ts);
  return (1e9 * ts.tv_sec) + ts.tv_nsec;
}

static void delay(void) {
  // inject latency to see any issues
  int r = rand() % 10000000000;
  printf("SCHED: delay for %d\n", r);
  while (r > 0) {
    --r;
  }
}

#endif
