import("stdfaust.lib");
ca = library("cascade.lib");


oscillators = os.osc(262), os.osc(330), os.osc(392);
N = outputs(oscillators);


energy = ca.cascade_exciter(N);


process = oscillators, energy : si.dot(N) ; 
