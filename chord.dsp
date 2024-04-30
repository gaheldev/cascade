import("stdfaust.lib");
ca = library("cascade.lib");

oscillators = os.osc(262), os.osc(330), os.osc(392);
N = outputs(oscillators);


// normalize(x) = x : par(i, outputs(x), _ / ba.slidingSum(outputs(x), x));

energy = ca.cascade_exciter(N);


process = oscillators, energy : si.dot(N) ; 
