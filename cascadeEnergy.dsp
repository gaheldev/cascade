declare name 	"cascadeEnergy";
declare author 	"gahel";
declare copyright "Gahel";
declare version "1.0";
declare license "STK-4.3";

import("stdfaust.lib");

// E(i,t) = E(i,t-1) + dt * (-nuk(i)*E(i,t-1) + T(E(i-1,t-1), E(i,t-1) - T(i, i+1) + noise)

source = hslider("E0",1,0,100,0.01);
sink = hslider("En",1,0,100,0.01);

threshold = 0.0001; // minimum energy levels
N = 5;


dt = ba.samp2sec(1);
// dt = 1;

nu = 10^hslider("nu",1,-10,10,0.01);
// nu = 0;
k0 = 10^hslider("k0", 1, -10, 10, 0.01);
lambda = hslider("lambda", 2, 1.01, 10, 0.01);

a = hslider("alpha", 0.1, threshold, 1/2 - threshold, 0.01); // alpha in the paper
b = hslider("beta", 0.9, 1/2 + threshold, 10, 0.01); // beta in the paper


k(i) = k0 * (lambda)^(i+1); // index starts from 0, paper starts from 1




idle = par(i,N,_);




d(i) = nu*(k(i))^(2);

dissipation = case {
    (0) => _*0;
    (i) => *(-dt*d(i));
};

dissipate = idle : par(i,N,dissipation(i));



f(e1,e2) = 1 / ((e2/e1)^a + (e2/e1)^b);



T(i, e1,e2) = f(e1,e2) *( k(i) * (max(e2,threshold))^(3/2) );

add_transfer(i, e1, e2) =   dt * T(i, e1, e2);
sub_transfer(i, e1, e2) = - dt * T(i, e1, e2);

select_and_next(i) = ba.selector(i,N), ba.selector(i+1,N);

transfer_from_lower = idle
                      <: ba.selector(0,N) * 0, // E(0) is unchanged                        
                         par(i, N-2, select_and_next(i) : add_transfer(i+1) ), // transfer 0->1, 1->2, ..., n-2->n-1  
                         ba.selector(N-1,N) * 0; // E(N) is unchanged
                         //  select i-1 and i and apply T(i) 
                         // /!\ we're counting from 0 to N-2 for E(1) to E(N)


transfer_to_higher = idle
                     <: ba.selector(0,N) * 0, // E(0) is unchanged  
                        par(i, N-2, select_and_next(i+1) : sub_transfer(i+2) ), // transfer 2->1, ..., n-1->n-2
                        ba.selector(N-1,N) * 0; // E(N) is unchanged
                        //  select i and i+1 and apply T(i+1) 
                        // /!\ we're counting from 0 to N-2 for E(0) to E(N-1)



eta = hslider("noise", 1, 0, 100, 0.01);
g(i) = eta * k(i)^(5/4) * _^(1/2);
noise_generator(i) = no.gnoise(10) * g(i);

add_noise = case {
    (0) => _ + 0;
    (i) =>_ <: _, dt * noise_generator(i) :> _;
};

noise = idle : par(i,N,add_noise(i));




constrain_to_positive = idle : par(i, N, max(threshold, _)); // Energie levels have to be > 0




E = idle 
    : constrain_to_positive
    <: idle, dissipate, transfer_from_lower, transfer_to_higher//, noise
    :> idle;

energy = E ~ ( _*0 + source, par(i, N-2, _), _*0 + sink );


process = energy;
