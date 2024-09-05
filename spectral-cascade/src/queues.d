

struct RoundRobin(int numberOfElements)
{
public:

    static assert(numberOfElements > 0, "Round robin requires at least 1 element");
    
    /// Return an avaiblable element if possible
    /// If non is available, returns oldest element that was returned
    int next()
    {
        return _getLessBusy();
    }

    void reset()
    {
        _busyness = 0;
    }

    void markBusy(int i)
    {
        _busyness[i] += numberOfElements;

        foreach (n; 0..numberOfElements)
        {
            if (_busyness[n] > 1)
                _busyness[n] -= 1;
        }
    }

    void markFree(int i)
    {
        _busyness[i] = 0;
    }

    void markFreeing(int i)
    {
        _busyness[i] = 0.5;
    }

private:

    // 0   : free
    // 0.5 : freeing
    // >=1 : busy ponderation
    float[numberOfElements] _busyness = 0;

    int _getLessBusy()
    {
        float min = numberOfElements;
        int minIndex = -1;
        foreach (i; 0..numberOfElements)
        {
            if (_busyness[i] == 0)
                return i;
            if (_busyness[i] < min)
            {
                min = _busyness[i];
                minIndex = i;
            }
        }
        return minIndex;
    }
}

unittest
{
    RoundRobin!3 r;
    r.markBusy(0);
    r.markBusy(1);
    assert(r.next == 2);

    r.markBusy(2);

    r.markFreeing(1);
    assert(r.next == 1);

    r.markFree(0);
    assert(r.next == 0);
}


struct Queue(T, size_t N)
{
nothrow @nogc:
public:
    static assert(N > 0, "Queue must have a size > 0");

    void empty()
    {
        if (isEmpty) return;
        front = 0;
        length = 0;
    }

    bool isEmpty() const
    {
        return length == 0;
    }

    bool isFull() const
    {
        return length == N;
    }

    /// Does nothing if queue is full
    void push(T item)
    {
        if (isFull) return;
        size_t back = (front + length) % N;
        data[back] = item;
        length++;
    }

    /// fails if queue is empty
    T pop()
    in (!isEmpty, "Queue is empty, cannot pop a value")
    {
        T item = data[front];
        front = (front + 1) % N;
        length--;
        return item;
    }

    /// fails if queue is empty
    T peek() const
    in (!isEmpty, "Queue is empty, cannot pop a value")
    {
        return data[front];
    }

    size_t capacity() const
    {
        return N;
    }

    size_t size() const
    {
        return length;
    }

private:

    T[N] data;
    size_t front = 0;
    size_t length = 0;

}


unittest
{
    // Test queue of integers
    {
        Queue!(int, 3) q;

        assert(q.isEmpty);
        assert(!q.isFull);
        assert(q.capacity == 3);
        assert(q.size == 0);

        q.push(1);
        assert(!q.isEmpty);

        q.push(2);
        q.push(3);

        assert(q.isFull);
        assert(q.size == 3);

        assert(q.peek == 1);
        assert(q.pop == 1);
        assert(q.size == 2);

        q.push(4);
        assert(q.isFull);

        assert(q.pop == 2);
        assert(q.pop == 3);
        assert(q.pop == 4);

        assert(q.isEmpty);
    }

    // Test queue of strings
    {
        Queue!(string, 2) q;

        q.push("hello");
        assert(q.peek == "hello");
        assert(q.size == 1);

        q.push("world");
        assert(q.isFull);

        assert(q.pop == "hello");
        assert(q.pop == "world");
        assert(q.isEmpty);
    }

    // Test circular behavior
    {
        Queue!(int, 3) q;

        q.push(1);
        q.push(2);
        q.push(3);
        assert(q.pop == 1);
        q.push(4);
        assert(q.pop == 2);
        assert(q.pop == 3);
        assert(q.pop == 4);
        assert(q.isEmpty);
    }

    // Test overflow
    {
        Queue!(int, 2) q;

        assert(q.isEmpty);
        q.push(1);
        q.push(2);
        assert(q.isFull);

        // push should do nothing
        q.push(3);
        assert(q.pop == 1);
        assert(q.pop == 2);
    }
}