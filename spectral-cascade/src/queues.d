import std.algorithm.sorting : sort;
import std.algorithm : min, max;


struct RoundRobin(int numberOfElements)
{
public:

    static assert(numberOfElements > 0, "Round robin requires at least 1 element");

    /// max number of elements actually used in RoundRobin;
    @property int maxElt() { return _maxElt; }
    @property int maxElt(int value)
    {
        _maxElt = min(value, numberOfElements);
        _maxElt = max(_maxElt, 0);
        return _maxElt;
    }
    
    /// Return an avaiblable element if possible
    /// If non is available, returns oldest element that was returned
    int next()
    {
        return _getLessBusy();
    }


    void bubbleSort(ref int[numberOfElements] a)
    {
        foreach (i; 0..maxElt-1)
        {
            foreach (j; 0..maxElt-i-1)
            {
                if (_busyness[a[j]] > _busyness[a[j+1]])
                {
                    int tmp = a[j];
                    a[j] = a[j+1];
                    a[j+1] = tmp;
                }
            }
        }
    }

    int[numberOfElements] scheduled()
    {
        bool _sort_function(int a, int b)
        {
            if (a >= maxElt && b < maxElt)
                return false;
            else if (a < maxElt && b >= maxElt)
                return true;
            else
                return _busyness[a] < _busyness[b];
        }

        int[numberOfElements] idx;
        foreach (i; 0..idx.length)
            idx[i] = _indexes[i];

        /* sort!(_sort_function)(idx[]); */
        bubbleSort(idx);
        return idx;
    }

    void reset()
    {
        _busyness = 0;
        _initIndexes();
    }

    void markBusy(int i)
    {
        _updateBusyness(i, 1, float.infinity, 1);
    }

    void markFree(int i)
    {
        _busyness[i] = 0;
    }

    void markFreeing(int i)
    {
        _updateBusyness(i, 0.1, 0.5, 0.01);
    }

    // Weight elements from first freeing to last freeing
    void markSlowlyFreeing(int i)
    {
        _updateBusyness(i, 0.5, 1, 0.01);
    }

private:

    // 0      : free
    // >= 0.1 : freeing
    // >= 0.5 : slowly freeing
    // >= 1   : busy ponderation
    float[numberOfElements] _busyness = 0;
    int[numberOfElements] _indexes;
    int _maxElt = numberOfElements;

    void _updateBusyness(int i, float floor, float ceil, float step)
    {
        assert((floor + maxElt * step) < ceil);
        foreach (n; 0..maxElt)
        {
            if (_busyness[n] > floor && _busyness[n] < ceil)
                _busyness[n] -= step;
        }
        _busyness[i] = floor + maxElt * step;
    }

    int _getLessBusy()
    {
        float min = float.infinity;
        int minIndex = -1;
        foreach (i; 0..maxElt)
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

    void _initIndexes()
    {
        foreach (i; 0..numberOfElements)
            _indexes[i] = i;
    }
}

// Test RoundRobin
unittest
{
    import std.stdio;
    RoundRobin!3 r;

    // Test Busy
    {
        r.reset();
        r.markBusy(0);
        assert(r.next == 1);
        assert(r.scheduled == [1,2,0]);
        r.markBusy(1);
        assert(r.next == 2);
        assert(r._busyness == [3,4,0]);
        assert(r.scheduled == [2,0,1]);

        r.markBusy(2);
        assert(r.scheduled == [0,1,2]);
    }

    // Test order of slowly freeing
    {
        r.markSlowlyFreeing(1);
        assert(r.next == 1);
        assert(r.scheduled == [1,0,2]);

        r.markSlowlyFreeing(2);
        assert(r.next == 1);
        assert(r.scheduled == [1,2,0]);

        r.markBusy(1);
        assert(r.next == 2);
        assert(r.scheduled == [2,0,1]);

        r.markSlowlyFreeing(0);
        assert(r.next == 2);
        assert(r.scheduled == [2,0,1]);

        r.markBusy(2);
        assert(r.next == 0);
        assert(r.scheduled == [0,1,2]);

        r.markSlowlyFreeing(2);
        assert(r.next == 0);
        assert(r.scheduled == [0,2,1]);

        r.markSlowlyFreeing(1);
        assert(r.next == 0);
        assert(r.scheduled == [0,2,1]);

        r.markFree(1);
        assert(r.next == 1);
        assert(r.scheduled == [1,0,2]);

        r.markBusy(1);
        assert(r.next == 0);
        assert(r.scheduled == [0,2,1]);

        r.markSlowlyFreeing(1);
        assert(r.next == 0);
        assert(r.scheduled == [0,2,1]);

        r.markBusy(0);
        assert(r.next == 2);
        assert(r.scheduled == [2,1,0]);

        r.markSlowlyFreeing(0);
        assert(r.next == 2);
        assert(r.scheduled == [2,1,0]);

        r.markBusy(2);
        assert(r.next == 1);
        assert(r.scheduled == [1,0,2]);

        r.markSlowlyFreeing(2);
        assert(r.next == 1);
        assert(r.scheduled == [1,0,2]);

    }

    // Test bubblesort
    {
        r.reset();
        r._busyness = [1,2,0];
        int[3] idx = [0,1,2];
        r.bubbleSort(idx);
        assert(idx == [2,0,1]);

        r.maxElt = 2;
        r._busyness = [2,1,0];
        idx = [0,1,2];
        r.bubbleSort(idx);
        assert(idx == [1,0,2]);
    }

    // Test change of maxElt
    {
        r.reset();
        assert(r._busyness == [0,0,0]);

        r.maxElt = 2;
        assert(r.scheduled == [0,1,2]);

        r.markBusy(0);
        assert(r._indexes == [0,1,2]);
        assert(r._busyness == [3,0,0]);
        assert(r.next == 1);
        assert(r.scheduled == [1,0,2]);
        // double check scheduled() has no side effect
        assert(r.next == 1);

        r.markBusy(1);
        assert(r.next == 0);

        r.markFreeing(1);
        assert(r.next == 1);
        assert(r.scheduled == [1,0,2]);

        r.markFree(0);
        assert(r.next == 0);
        assert(r.scheduled == [0,1,2]);
    }
}


struct Queue(T, size_t N)
{
nothrow @nogc:
public:
    static assert(N > 0, "Queue must have a size > 0");

    void empty()
    {
        if (isEmpty) return;
        _front = 0;
        _length = 0;
    }

    bool isEmpty() const
    {
        return _length == 0;
    }

    bool isFull() const
    {
        return _length == N;
    }

    /// Does nothing if queue is full
    void push(T item)
    {
        if (isFull) return;
        size_t back = (_front + _length) % N;
        data[back] = item;
        _length++;
    }

    /// fails if queue is empty
    T pop()
    in (!isEmpty, "Queue is empty, cannot pop a value")
    {
        T item = data[_front];
        _front = (_front + 1) % N;
        _length--;
        return item;
    }

    /// fails if queue is empty
    T peek() const
    in (!isEmpty, "Queue is empty, cannot pop a value")
    {
        return data[_front];
    }

    size_t capacity() const
    {
        return N;
    }

    size_t length() const
    {
        return _length;
    }

private:

    T[N] data;
    size_t _front = 0;
    size_t _length = 0;

}



// Test Queue
unittest
{
    // Test queue of integers
    {
        Queue!(int, 3) q;

        assert(q.isEmpty);
        assert(!q.isFull);
        assert(q.capacity == 3);
        assert(q.length == 0);

        q.push(1);
        assert(!q.isEmpty);

        q.push(2);
        q.push(3);

        assert(q.isFull);
        assert(q.length == 3);

        assert(q.peek == 1);
        assert(q.pop == 1);
        assert(q.length == 2);

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
        assert(q.length == 1);

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
