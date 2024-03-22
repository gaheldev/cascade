import("stdfaust.lib");
E = component("cascadeEnergy.dsp");

id = 1, 1, 1;

process = os.osc(262), os.osc(330), os.osc(392) , E : route(6,6, 1,1,4,2, 2,3,5,4, 3,5,6,6): *, *, * :> _ <: _,_ ; 