import std.math;
import std.algorithm;
import config;


class Solver
{
@safe pure nothrow @nogc:
public:

    this()
    {
    }

    void excite(float amount)
    {
        foreach (n; 1.._N-1)
            levels[n] = amount;
    }

    void nextStep()
    {
        reset_cache(c_T);
        foreach (n; 0..cast(int) levels.length)
            _newLevels[n] = nextLevel(n);
        levels = _newLevels;
    }
	
    float nextLevel(int n)
    {
        if (n==0 || n==_N) return levels[n];

        // TODO: stop processing below a small value and return 0
        float e = levels[n] + delta_t * (  dissipation(n)
                                         + T(n)
                                         - T(n+1)
                                         + g(n)*noise()
                                        );
        return max(e,0);
    }

    float lambda_pow(int i)
    {
        if (!USE_CACHE) return lambda^^i;

        if (c_lambda_pow[i] != -1)
            return c_lambda_pow[i];
        
        float v;
        if (i == 0)
            return 1;
        else if (i == 1)
            v = lambda;
        else
            v = lambda_pow(i-1) * lambda;

        c_lambda_pow[i] = v;
        return v;
    }

    float k(int i)
    {
        if (!USE_CACHE) return k0 * lambda_pow(i+1);

        if (c_k[i] == -1)
            c_k[i] = k0 * lambda_pow(i+1);
        return c_k[i];
    }

    float f(float x)
    {
        if (x<=DENORMAL) return 0;

        return a / (x^^alpha * (1 + (a/b) * x^^(beta-alpha)));
    }

    float dissipation(int i)
    {
        if (i==0 || i==_N) return 0;

        return -nu * k(i)^^2 * levels[i];
    }

    float T(int i)
    {
        if (eta==0) return 0; // DEBUG: to test performance
        if (USE_CACHE && c_T[i] != -1)
            return c_T[i];
            
        float e_from = levels[i-1];
        float e_to = levels[i];
        if (e_from<=DENORMAL) return 0;
        if (e_to<=DENORMAL) return 0;

        c_T[i] = k(i) * e_to^^1.5 * f(e_to/e_from);
        return c_T[i];
    }

    float noise()
    {
        // TODO: return gauss_sample / delta_t^^0.5
        return 0;
    }

    float g(int i)
    {
        return 0; // DEBUG: to exclude from computation
        if (eta==0) return 0;
        return eta * k(i)^^delta * levels[i]^^gamma;
    }
    
    float[N_HARMONICS+2] levels = 1.0;
    float delta_t = 1.0/48000;

    @property float nu() { return m_nu; }
    @property float nu(float value)
    {
        if (value != m_nu)
            reset_cache(c_dissipation);
        return m_nu = value;
    }

    @property float k0() { return m_k0; }
    @property float k0(float value)
    {
        if (value != m_k0)
            reset_cache(c_k);
        return m_k0 = value;
    }


    @property float lambda() { return m_lambda; }
    @property float lambda(float value)
    {
        if (value != m_lambda)
            reset_cache(c_lambda_pow);
        return m_lambda = value;
    }

    float alpha = 0.1;
    float beta = 0.9;
    float a = 1;
    float b = 1;
    float eta = 1;
	

private:
    float delta = 1.0/2;
    float gamma = 5.0/4;
    int _N = N_HARMONICS+1;
    float[N_HARMONICS+2] _newLevels;

    float m_nu = 1;
    float m_k0 = 1;
	float m_lambda = 1.5;

    const int CACHE_SIZE = 2 * N_HARMONICS; // a bit extra space
    float[CACHE_SIZE] c_lambda_pow = -1;
    float[CACHE_SIZE] c_k = -1;
    float[CACHE_SIZE] c_T = -1;
    float[CACHE_SIZE] c_dissipation = -1;

    void reset_cache(ref float[CACHE_SIZE] cache) { cache[0..$] = -1.0; }

}
