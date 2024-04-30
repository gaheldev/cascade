import("stdfaust.lib");
ca = library("cascade.lib");


excite = button("Excite");

E0 = 1;
En = 0.1;

process = excite, E0, En : ca.E;
