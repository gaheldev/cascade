import solver;
import config;
import std.stdio;


void main()
{
	float[N_HARMONICS+2] levels = 0.1;
    levels[0] = 1.0;

	Solver sol = new Solver();
	sol.levels = levels;

	foreach (i; 0..20)
	{
		writeln(sol.levels);
		sol.nextStep();
	}
		
}
