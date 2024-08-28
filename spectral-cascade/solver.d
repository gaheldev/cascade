import std.math;
import std.algorithm;
import config;


const float DENORMAL = 0.0001;

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

	float k(int i)
	{
		return k0 * lambda^^(i+1);
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
		float e_from = levels[i-1];
		float e_to = levels[i];
		if (e_from<=DENORMAL) return 0;
		if (e_to<=DENORMAL) return 0;

		return k(i) * e_to^^1.5 * f(e_to/e_from);
	}

	float noise()
	{
		// TODO: return gauss_sample / delta_t^^0.5
		return 0;
	}

	float g(int i)
	{
        if (eta==0) return 0;
		return eta * k(i)^^delta * levels[i]^^gamma;
	}
	
	float[N_HARMONICS+2] levels = 1.0;
	float delta_t = 1.0/48000;
	float nu = 1;
	float k0 = 1;
	float lambda = 1.5;
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
		
}
