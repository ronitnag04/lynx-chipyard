#ifndef QUEUEAGAIN_H
#define QUEUEAGAIN_H

#define qprintf(...) (0)
//#define qprintf(...) printf(__VA_ARGS__)

typedef struct {
  uint64_t est_acc_ns;
  uint64_t metadata;
} qagain_elem_t;

#define MAX_QUEUEAGAIN_SIZE (RQUEUE_SIZE)

typedef struct {
  elem_t items[MAX_QUEUEAGAIN_SIZE];
  size_t front;
  size_t rear;
  size_t size;
  uint64_t sum_ns;
  size_t max_size;
} queueagain_t;

void qagain_init(queueagain_t* q) {
  q->front = 0;
  q->rear = 0;
  q->sum_ns = 0;
  q->size = 0;
  q->max_size = 0;
}

bool qagain_empty(queueagain_t* q) { return q->size == 0; }
bool qagain_full(queueagain_t* q) { return q->size == MAX_QUEUEAGAIN_SIZE; }
size_t qagain_size(queueagain_t* q) { return q->size; }
size_t qagain_maxsize(queueagain_t* q) { return q->max_size; }

bool qagain_enqueue(queueagain_t* q, elem_t* value) {
  if (qagain_full(q)) {
    return false;
  }

  q->items[q->rear].est_acc_ns = value->est_acc_ns;
  q->items[q->rear].metadata = value->metadata;
  q->rear = (q->rear + 1) % MAX_QUEUEAGAIN_SIZE;
  q->size++;
  if (q->size > q->max_size) {
    q->max_size = q->size;
  }

  q->sum_ns += value->est_acc_ns;
  qprintf("QUEUE: enqueued sum_ns:%lu\n", q->sum_ns);

  qprintf("QUEUE: enqueued f:%d r:%d m:%ld\n", q->front, q->rear, value.metadata);
  return true;
}

bool qagain_dequeue(queueagain_t* q) {
  if (qagain_empty(q)) {
    return false;
  }

  q->sum_ns -= q->items[q->front].est_acc_ns;
  qprintf("QUEUE: dequeued sum_ns:%lu\n", q->sum_ns);

  uint64_t old_meta = q->items[q->front].metadata;

  q->front = (q->front + 1) % MAX_QUEUEAGAIN_SIZE;
  q->size--;

  qprintf("QUEUE: dequeued f:%d r:%d m:%ld\n", q->front, q->rear, old_meta);
  return true;
}

bool qagain_peek(queueagain_t* q, elem_t* peeked) {
  if (qagain_empty(q)) {
    qprintf("QUEUE: empty\n");
    return false;
  }

  *peeked = q->items[q->front];

  qprintf("QUEUE: peeked\n");
  return true;
}

uint64_t qagain_sum(queueagain_t* q) {
  return q->sum_ns;
}

bool qagain_poke(queueagain_t* q, elem_t* poke) {
  if (qagain_empty(q)) {
    qprintf("QUEUE: empty\n");
    return false;
  }

  q->items[q->front].est_acc_ns = poke->est_acc_ns;
  q->items[q->front].metadata = poke->metadata;

  qprintf("QUEUE: poked\n");
  return true;
}

#endif
