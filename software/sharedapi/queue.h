#ifndef QUEUE_H
#define QUEUE_H

// TODO: missing proper headers here

#define METADATA_MASK ((uint64_t)1)
typedef struct {
  uint64_t ns_since_epoch;
  uint64_t est_acc_ns;
  uint64_t metadata;
} elem_t;

#define MAX_QUEUE_SIZE 2

typedef struct {
  elem_t items[MAX_QUEUE_SIZE];
  size_t front;
  size_t rear;
  uint64_t sum_ns;
} queue_t;

void q_init(queue_t* q) {
  q->front = -1;
  q->rear = -1;
  q->sum_ns = 0;
}

bool q_empty(queue_t* q) { return q->front == -1; }
bool q_full(queue_t* q) { return ((q->rear + 1) % MAX_QUEUE_SIZE) == q->front; }
size_t q_size(queue_t* q) { return q_empty(q) ? 0 : (q->front <= q->rear ? q->rear - q->front + 1 : MAX_QUEUE_SIZE - q->front + q->rear + 1); }

bool q_enqueue(queue_t* q, elem_t value) {
  if (q_full(q)) {
    printf("QUEUE: full\n");
    return false;
  }

  if (q_empty(q)) {
    q->front = q->rear = 0;
  } else {
    q->rear = (q->rear + 1) % MAX_QUEUE_SIZE;
  }

  q->items[q->rear] = value;
#ifdef FCFS_RUNTIME_SKIP
  q->sum_ns += value.est_acc_ns;
#endif
  printf("QUEUE: enqueued\n");
  return true;
}

bool q_dequeue(queue_t* q) {
  if (q_empty(q)) {
    printf("QUEUE: empty\n");
    return false;
  }

#ifdef FCFS_RUNTIME_SKIP
  q->sum_ns -= q->items[q->front].est_acc_ns;
#endif

  if (q->front == q->rear) {
    q->front = -1;
    q->rear = -1;
  } else {
    q->front = (q->front + 1) % MAX_QUEUE_SIZE;
  }

  printf("QUEUE: dequeued\n");
  return true;
}

bool q_peek(queue_t* q, elem_t* peeked) {
  if (q_empty(q)) {
    printf("QUEUE: empty\n");
    return false;
  }

  *peeked = q->items[q->front];

  printf("QUEUE: peeked\n");
  return true;
}

uint64_t q_sum(queue_t* q) {
  return q->sum_ns;
}

bool q_poke(queue_t* q, elem_t poke) {
  if (q_empty(q)) {
    printf("QUEUE: empty\n");
    return false;
  }

  q->items[q->front] = poke;

  printf("QUEUE: poked\n");
  return true;
}

#endif
