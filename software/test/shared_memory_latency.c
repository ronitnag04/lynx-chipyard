#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/mman.h>

#define NUM_ITERATIONS 1000000

// Structure to hold shared data
typedef struct {
    volatile int flag;
} shared_data_t;

shared_data_t *shared_data;

void *thread1_func(void *arg) {
    struct timeval start, end;
    long long total_time = 0;

    for (int i = 0; i < NUM_ITERATIONS; i++) {
        gettimeofday(&start, NULL);
        // Signal thread 2
        shared_data->flag = 1;
        // Wait for thread 2 to respond
        while (shared_data->flag == 1);
        gettimeofday(&end, NULL);

        total_time += (end.tv_sec - start.tv_sec) * 1000000LL + (end.tv_usec - start.tv_usec);
    }

    printf("Thread 1: Average latency: %.2f nanoseconds\n", (double)total_time * 1000 / NUM_ITERATIONS);
    pthread_exit(NULL);
}

void *thread2_func(void *arg) {
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        // Wait for signal from thread 1
        while (shared_data->flag == 0);
        // Respond to thread 1
        shared_data->flag = 0;
    }
    pthread_exit(NULL);
}

int main() {
    pthread_t thread1, thread2;
    pthread_attr_t attr;

    // Initialize shared memory
    shared_data = (shared_data_t *)mmap(NULL, sizeof(shared_data_t),
                                        PROT_READ | PROT_WRITE,
                                        MAP_SHARED | MAP_ANONYMOUS, -1, 0);

    if (shared_data == MAP_FAILED) {
        perror("mmap failed");
        return 1;
    }

    shared_data->flag = 0; // Initialize flag

    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);

    if (pthread_create(&thread1, &attr, thread1_func, NULL) != 0) {
        perror("Thread creation failed");
        return 1;
    }

    if (pthread_create(&thread2, &attr, thread2_func, NULL) != 0) {
        perror("Thread creation failed");
        return 1;
    }

    pthread_join(thread1, NULL);
    pthread_join(thread2, NULL);

    pthread_attr_destroy(&attr);

    // Unmap shared memory
    if (munmap(shared_data, sizeof(shared_data_t)) == -1) {
        perror("munmap failed");
        return 1;
    }

    return 0;
}
