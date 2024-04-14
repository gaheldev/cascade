import("stdfaust.lib");
E = component("cascadeEnergy.dsp");

id = 1, 1, 1;

// energies = E : par(i,3,abs(_));// : par(i,3,_/ma.MAX);

// process = os.osc(262), os.osc(330), os.osc(392) , energies : route(6,6, 1,1,4,2, 2,3,5,4, 3,5,6,6): *, *, * :> _ <: _,_ ;

process = os.osc(262), os.osc(330), os.osc(392) :> _ * hslider("gain", 0.1, 0, 0.33, 0.01) <: _,_ ;