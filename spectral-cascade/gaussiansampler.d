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
        return n / sqrt(steps/3.0);
    }
}
