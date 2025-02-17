#ifndef QUEUE_H
#define QUEUE_H

#define qprintf(...) (0)
//#define qprintf(...) printf(__VA_ARGS__)

#define METADATA_MASK ((uint64_t)1)
typedef struct {
  uint64_t ns_since_epoch;
  uint64_t est_acc_ns;
  uint64_t metadata;
  bool running;
  pthread_cond_t* thread_cond;
} elem_t;

#ifndef RQUEUE_SIZE
#define RQUEUE_SIZE (100)
#endif
#define MAX_QUEUE_SIZE (RQUEUE_SIZE)

typedef struct {
  elem_t items[MAX_QUEUE_SIZE];
  size_t front;
  size_t rear;
  size_t size;
  uint64_t sum_ns;
  pthread_cond_t* full_cond;
  size_t max_size;
} queue_t;

void q_init(queue_t* q) {
  q->front = 0;
  q->rear = 0;
  q->sum_ns = 0;
  q->size = 0;
  q->max_size = 0;

  q->full_cond = (pthread_cond_t *)malloc(sizeof(pthread_cond_t));
  pthread_cond_init(q->full_cond, NULL);
  for (size_t i = 0; i < MAX_QUEUE_SIZE; ++i) {
    q->items[i].thread_cond = (pthread_cond_t *)malloc(sizeof(pthread_cond_t));
    pthread_cond_init(q->items[i].thread_cond, NULL);
  }
}

bool q_empty(queue_t* q) { return q->size == 0; }
bool q_full(queue_t* q) { return q->size == MAX_QUEUE_SIZE; }
size_t q_size(queue_t* q) { return q->size; }
size_t q_maxsize(queue_t* q) { return q->max_size; }

bool q_found(queue_t* q, uint64_t meta) {
  if (q_empty(q)) {
    return false;
  }

  size_t i = q->front;
  size_t count = 0;
  while (count < q->size) {
    if (q->items[i].metadata == meta) {
      return true;
    }
    i = (i + 1) % MAX_QUEUE_SIZE;
    count++;
  }

  return false;
}

//#define KEEP_ASSERTS

bool q_enqueue(queue_t* q, elem_t value) {
  if (q_full(q)) {
    return false;
  }

#ifdef KEEP_ASSERTS
  assert(!q_found(q, value.metadata));
#endif
  q->items[q->rear] = value;
  q->rear = (q->rear + 1) % MAX_QUEUE_SIZE;
  q->size++;
  if (q->size > q->max_size) {
    q->max_size = q->size;
  }

#if defined(FCFS_RUNTIME_SKIP) || defined(FCFS_RUNTIME_SKIP_OPT) || defined(FCFS_BLOCK_SPINLOCK)
  q->sum_ns += value.est_acc_ns;
  qprintf("QUEUE: enqueued sum_ns:%lu\n", q->sum_ns);
#endif

  qprintf("QUEUE: enqueued f:%d r:%d m:%ld\n", q->front, q->rear, value.metadata);
  return true;
}

bool q_enqueue_ptr(queue_t* q, elem_t* value, pthread_cond_t** cond) {
  if (q_full(q)) {
    return false;
  }

#ifdef KEEP_ASSERTS
  assert(!q_found(q, value->metadata));
#endif
  q->items[q->rear].ns_since_epoch = value->ns_since_epoch;
  q->items[q->rear].est_acc_ns = value->est_acc_ns;
  q->items[q->rear].metadata = value->metadata;
  q->items[q->rear].running = value->running;
  *cond = q->items[q->rear].thread_cond;
  q->rear = (q->rear + 1) % MAX_QUEUE_SIZE;
  q->size++;
  if (q->size > q->max_size) {
    q->max_size = q->size;
  }

#if defined(FCFS_RUNTIME_SKIP) || defined(FCFS_RUNTIME_SKIP_OPT) || defined(FCFS_BLOCK_SPINLOCK)
  q->sum_ns += value->est_acc_ns;
  qprintf("QUEUE: enqueued sum_ns:%lu\n", q->sum_ns);
#endif

  qprintf("QUEUE: enqueued f:%d r:%d m:%ld\n", q->front, q->rear, value->metadata);
  return true;
}

bool q_dequeue(queue_t* q) {
  if (q_empty(q)) {
    return false;
  }

#if defined(FCFS_RUNTIME_SKIP) || defined(FCFS_RUNTIME_SKIP_OPT) || defined(FCFS_BLOCK_SPINLOCK)
  q->sum_ns -= q->items[q->front].est_acc_ns;
  qprintf("QUEUE: dequeued sum_ns:%lu\n", q->sum_ns);
#endif

  uint64_t old_meta = q->items[q->front].metadata;

  q->front = (q->front + 1) % MAX_QUEUE_SIZE;
  q->size--;

#ifdef KEEP_ASSERTS
  assert(!q_found(q, old_meta));
#endif

  qprintf("QUEUE: dequeued f:%d r:%d m:%ld\n", q->front, q->rear, old_meta);
  return true;
}

bool q_peek(queue_t* q, elem_t* peeked) {
  if (q_empty(q)) {
    qprintf("QUEUE: empty\n");
    return false;
  }

  *peeked = q->items[q->front];

  qprintf("QUEUE: peeked\n");
  return true;
}

uint64_t q_sum(queue_t* q) {
  return q->sum_ns;
}

bool q_poke(queue_t* q, elem_t poke) {
  if (q_empty(q)) {
    qprintf("QUEUE: empty\n");
    return false;
  }

  q->items[q->front] = poke;

  qprintf("QUEUE: poked\n");
  return true;
}

bool q_poke_running(queue_t* q, uint64_t time_ns) {
  if (q_empty(q)) {
    qprintf("QUEUE: empty\n");
    return false;
  }

  q->items[q->front].running = true;
  q->items[q->front].ns_since_epoch = time_ns;

  qprintf("QUEUE: poked\n");
  return true;
}

#endif
