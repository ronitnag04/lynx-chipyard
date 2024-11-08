#ifndef QUEUE_H
#define QUEUE_H

#define MAX_SIZE 100

// Defining the Queue structure
typedef struct {
                int items[MAX_SIZE];
                int front;
                int rear;
} Queue;

// Function to initialize the queue
void initializeQueue(Queue* q)
{
                q->front = -1;
                q->rear = 0;
}

// Function to check if the queue is empty
bool isEmpty(Queue* q) { return (q->front == q->rear - 1); }

// Function to check if the queue is full
bool isFull(Queue* q) { return (q->rear == MAX_SIZE); }

// Function to add an element to the queue (Enqueue
// operation)
bool enqueue(Queue* q, int value)
{
                if (isFull(q)) {
                                return false;
                }
                q->items[q->rear] = value;
                q->rear++;
                return true;
}

// Function to remove an element from the queue (Dequeue
// operation)
bool dequeue(Queue* q)
{
                if (isEmpty(q)) {
                                return false;
                }
                q->front++;
                return true;
}

// Function to get the element at the front of the queue
// (Peek operation)
bool peek(Queue* q, int* peeked)
{
                if (isEmpty(q)) {
                                return false;
                }
                *peeked = q->items[q->front + 1];
                return true;
}


#endif
