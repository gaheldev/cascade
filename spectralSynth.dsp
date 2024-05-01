declare options "[midi:on][nvoices:12]";

import("stdfaust.lib");
ca = library("cascade.lib");



N = 10; // number of harmonics

freq = hslider("freq",200,50,1000,0.01);
gain = hslider("gain",0.5,0,1,0.01);
gate = button("gate");

excite = (gate - gate') > 0; // only triggers on note on

oscillators = par(i,N, os.osc(freq*(i+1)));


energy = ca.cascade_to_excite(N, excite);


process = oscillators, energy : si.dot(N) * gain; 
