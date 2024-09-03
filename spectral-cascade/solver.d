import std.math;
// override some math functions
import dplug.core.math : pow = fast_pow, sqrt = fast_sqrt;
import std.algorithm;
import std.random;
import gaussiansampler : TableGaussianGenerator, FastPureRandomGenerator, PureRandomGenerator;
import config;


struct Solver
{
@safe pure nothrow @nogc:
public:

    void excite(float amount)
    {
        foreach (n; 1.._N-1)
            levels[n] = amount;
    }

    void nextStep()
    {
        _reset_cache(c_T);
        foreach (n; 0..cast(int) levels.length)
            _newLevels[n] = nextLevel(n);
        levels = _newLevels;
    }
	
    float nextLevel(int n)
    {
        if (n==0 || n==_N) return levels[n];
        if (levels[n] <= DENORMAL) return 0.0;

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

        return a * b / (b * x.pow(alpha) + a * x.pow(beta));
    }

    float dissipation(int i)
    {
        if (i==0 || i==_N) return 0;

        return -nu * k(i) * k(i) * levels[i];
    }

    float T(int i)
    {
        /* if (eta==0) return 0; // DEBUG: to test performance */
        if (USE_CACHE && c_T[i] != -1)
            return c_T[i];
            
        float e_from = levels[i-1];
        float e_to = levels[i];
        if (e_from<=DENORMAL) return 0;
        if (e_to<=DENORMAL) return 0;

        c_T[i] = k(i) * e_to.pow(1.5) * f(e_to/e_from);
        return c_T[i];
    }

    float noise()
    {
        if (eta==0) return 0;
        // return gauss_sample / delta_t^^0.5
        return _rng.gaussianNoise(0.0, _noise_stddev);
    }

    float k_delta(int i)
    {
        if (c_k_delta[i] == -1)
            c_k_delta[i] = k(i).pow(_delta);
        return c_k_delta[i];
    }

    float levels_gamma(int i)
    {
        if (c_levels_gamma[i] == -1)
            c_levels_gamma[i] = levels[i].pow(_delta);
        return c_levels_gamma[i];

    }

    float g(int i)
    {
        if (eta==0) return 0;
        return eta * k_delta(i) * levels_gamma(i);
    }
    
    float[N_HARMONICS+2] levels = 1.0;

    @property float delta_t() { return m_delta_t; }
    @property float delta_t(float value)
    {
        if (value != m_delta_t)
            _noise_stddev = _get_noise_stddev(value);
        return m_delta_t = value;
    }

    @property float nu() { return m_nu; }
    @property float nu(float value)
    {
        if (value != m_nu)
            _reset_cache(c_dissipation);
        return m_nu = value;
    }

    @property float k0() { return m_k0; }
    @property float k0(float value)
    {
        if (value != m_k0)
            _reset_cache(c_k);
        return m_k0 = value;
    }


    @property float lambda() { return m_lambda; }
    @property float lambda(float value)
    {
        if (value != m_lambda)
            _reset_cache(c_lambda_pow);
        return m_lambda = value;
    }

    float alpha = 0.1;
    float beta = 0.9;
    float a = 1;
    float b = 1;
    float eta = 1;
	

private:
    float _delta = 1.0/2;
    float _gamma = 5.0/4;
    int _N = N_HARMONICS+1;
    float[N_HARMONICS+2] _newLevels;

    // @properties
    float m_delta_t = 1.0/48000.0;
    float m_nu = 1;
    float m_k0 = 1;
	float m_lambda = 1.5;

    // rng
    TableGaussianGenerator!12345 _rng;
    // TODO: check std is correct (delta_t^^0.5 ?)
    float _get_noise_stddev(float delta_t) { return 1.0 / sqrt(delta_t); }
    float _noise_stddev = 1.0 / sqrt(1.0 / 48000.0); // 1 / (delta_t^^0.5)

    // caches
    const int CACHE_SIZE = 2 * N_HARMONICS; // a bit of extra space
    float[CACHE_SIZE] c_lambda_pow = -1;
    float[CACHE_SIZE] c_k = -1;
    float[CACHE_SIZE] c_T = -1;
    float[CACHE_SIZE] c_dissipation = -1;
    float[CACHE_SIZE] c_k_delta = -1;
    float[CACHE_SIZE] c_levels_gamma = -1;

    void _reset_cache(ref float[CACHE_SIZE] cache) { cache[0..$] = -1.0; }

}
