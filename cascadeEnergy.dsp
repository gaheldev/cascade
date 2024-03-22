declare name 	"cascadeEnergy";
declare author 	"gahel";
declare copyright "Gahel";
declare version "1.0";
declare license "STK-4.3";

import("stdfaust.lib");

// E(i,t) = E(i,t-1) + dt * (-nuk(i)*E(i,t-1) + T(E(i-1,t-1), E(i,t-1) - T(i, i+1) + noise)

source = 1;

nu = 0.5;
d(i) = -nu*(0.5)^(i);

N = 3;

dissipation = case {
    (0) => _;
    (3) => *(0);
    (i) => *(1+d(i));
};

noise(i) = no.noise;

add_noise = case {
    (0) => +(0);
    (3) => +(0);
    (i) => _ + noise(i);
};

a = 0.5;
T(i) = _, _ : _^(3/2+a), _^(-a) : _ + _; // T(Ei-1, Ei) TODO: substract transfer from i+1 to i

add_transfer = case {
    (0) => +(0);
    (i) => _, _ : T(i);
};


idle = par(i,N,_);
memoryline = par(i,N,_');
autorecursive = par(i,N,dissipation(i)); // : par(i,N,add_noise(i));
transfer = par(i,N,add_transfer(i));
remove_idle = route(6,3,4,1,5,2,6,3);

E = idle <: idle , autorecursive : route(6,8, 1,1,2,2,3,3, 4,4, 4,5,5,6, 5,7,6,8) : idle, transfer : remove_idle;
process = E ~ (source, _, _);