import("stdfaust.lib");
E = component("cascadeEnergy.dsp");


excite = button("Excite");
// excite = os.lf_imptrain(1/hslider("excite time (s)", 5, 1, 15, 0.1)); // DEBUG

E0 = 1;
En = 0.1;

process = excite, E0, En : E;
