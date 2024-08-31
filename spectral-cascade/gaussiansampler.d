import std.math : sqrt, log, sin, cos, PI;


struct PureRandomGenerator
{
@safe pure nothrow @nogc:
    private ulong state;

    this(ulong seed) 
    {
        state = seed;
    }

    ulong next() 
    {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        return state;
    }

    double uniform() 
    {
        return (next() & ((1UL << 53) - 1)) * (1.0 / (1UL << 53));
    }

    double gaussianNoise() 
    {
        double u1, u2;
        
        u1 = uniform();
        u2 = uniform();
        
        return sqrt(-2.0 * log(u1)) * cos(2 * PI * u2);
    }

    double gaussianNoise(double mean, double stddev) 
    {
        return mean + stddev * gaussianNoise();
    }

    double gaussianNoiseApprox(int steps)
    {
        double n = 0.0;
        foreach (i; 0..steps)
            n += uniform();
        return n / steps^^0.5;
    }
}


struct FastPureRandomGenerator
{
@safe pure nothrow @nogc:
    private uint state;

    this(uint seed) 
    {
        state = seed;
    }

    uint next() 
    {
        state = state * 1664525 + 1013904223;
        return state;
    }

    float uniform01() 
    {
        return (next() & 0x00FFFFFF) / cast(float)0x01000000;
    }

    float gaussianNoise(float mean, float stddev) 
    {
        float sum = 0.0f;
        foreach (_; 0..5)  // You can adjust this number for speed/quality trade-off
        {
            sum += uniform01();
        }
        return mean + stddev * (sum - 6.0f) * sqrt(1.0f / 12.0f);
    }
}

struct TableGaussianGenerator
{
@safe pure nothrow @nogc:
    private uint state;
    private enum TABLE_SIZE = 256;
    private immutable float[TABLE_SIZE] gaussianTable;

    this(uint seed) 
    {
        state = seed;
        gaussianTable = generateGaussianTable();
    }

    private static float[TABLE_SIZE] generateGaussianTable()
    {
        float[TABLE_SIZE] table;
        foreach (i; 0..TABLE_SIZE)
        {
            float x = (cast(float)i + 0.5f) / TABLE_SIZE;
            table[i] = sqrt(2.0f) * erfinv(2.0f * x - 1.0f);
        }
        return table;
    }

    uint next() 
    {
        state = state * 1664525 + 1013904223;
        return state;
    }

    float gaussianNoise(float mean, float stddev) 
    {
        uint index = next() & (TABLE_SIZE - 1);
        return mean + stddev * gaussianTable[index];
    }

}

// Simplified erfinv function (you might want to use a more accurate approximation)
private float erfinv(float x) @safe pure nothrow @nogc
{
    float w = -log((1.0f - x) * (1.0f + x));
    float p;
    if (w < 5.0f)
    {
        w = w - 2.5f;
        p = 2.81022636e-08f;
        p = 3.43273939e-07f + p * w;
        p = -3.5233877e-06f + p * w;
        p = -4.39150654e-06f + p * w;
        p = 0.00021858087f + p * w;
        p = -0.00125372503f + p * w;
        p = -0.00417768164f + p * w;
        p = 0.246640727f + p * w;
        p = 1.50140941f + p * w;
    }
    else
    {
        w = sqrt(w) - 3.0f;
        p = -0.000200214257f;
        p = 0.000100950558f + p * w;
        p = 0.00134934322f + p * w;
        p = -0.00367342844f + p * w;
        p = 0.00573950773f + p * w;
        p = -0.0076224613f + p * w;
        p = 0.00943887047f + p * w;
        p = 1.00167406f + p * w;
        p = 2.83297682f + p * w;
    }
    return p * x;
}
