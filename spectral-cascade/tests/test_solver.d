import solver;
import std.stdio;


void main()
{
	float[] levels = [1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1];

	Solver sol = new Solver();
	sol.levels = levels;

	foreach (i; 0..20)
	{
		writeln(sol.levels);
		sol.nextStep();
	}
		
}
