import solver;
import config;
import std.stdio;


void main()
{
	float[N_HARMONICS+2] levels = 0.1;
    levels[0] = 1.0;

	Solver sol = new Solver();
    foreach (n; 0..10)
    {
        sol.levels = levels;

        foreach (i; 0..1000)
        {
            /* writeln(sol.levels); */
            sol.nextStep();
        }
    }
}
