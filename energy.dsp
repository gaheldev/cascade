declare name 	"Energy";
declare author 	"gahel";
declare copyright "Gahel";
declare version "1.0";
declare license "STK-4.3";

import("stdfaust.lib");

// E(i,t) = E(i,t-1) + dt * (-nuk(i)*E(i,t-1) + T(E(i-1,t-1), E(i,t-1) - T(i, i+1) + noise)


/* =========== Settings ==============*/

source = hslider("source",1,0,1,0.01);
sink = hslider("sink",0.1,0,1,0.01);

N = 10;


dt = ba.samp2sec(1);
// dt = 1;

nu = hslider("nu",1,0,1,0.01);
k0 = hslider("k0", 1, 0, 10, 0.01);
lambda = hslider("lambda", 1.5, 1 + ma.EPSILON, 3, 0.01);

alpha = hslider("alpha", 0.1, ma.EPSILON, 1/2 - ma.EPSILON, 0.01);
beta = hslider("beta", 0.9, 1/2 + ma.EPSILON, 10, 0.01); 

a = hslider("a", 1, 0, 10, 0.01); 
b = hslider("b", 1, ma.EPSILON, 10, 0.01); 

k(i) = k0 * (lambda)^(i+1); // index starts from 0, paper starts from 1




idle = par(i,N,_);



/* =========== Dissipation ==============*/

d(i) = nu*(k(i))^(2);

dissipation = case {
    (0) => _*0;
    (i) => _*(-dt*d(i));
};

dissipate = idle : par(i,N,dissipation(i));



/* =========== Transfers ==============*/

// Make divisions safe again
max_clip(x) = max(ma.INFINITY * -1, min(ma.INFINITY, x)); // clip value between -INF and INF
safe_div(x, y) = max_clip(ba.if(y < 0, x / min(ma.EPSILON * -1, y), x / max(ma.EPSILON, y))); // divide at most by ±EPSILON, 0/anything = 0


f(e1,e2) = safe_div(a, safe_div(e2,e1)^alpha * (1 + safe_div(a,b) * safe_div(e2,e1)^(beta-alpha)) );



T(i, e1,e2) = f(e1,e2) *( k(i) * (max(e2,ma.EPSILON))^(3/2) );

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



/* =========== Noise ==============*/

eta = hslider("noise", 1, 0, 2, 0.001);
g(i) = eta * k(i)^(1/2) * _^(5/4);

noise_generator(i) = no.gnoise(10) * g(i);

// noise_speed = hslider("Noise speed", 1, 0, 10, 0.1);
// sin_noise(x) = (sin(x*noise_speed) + sin(ma.PI/2*x*noise_speed) + sin(sqrt(2)*x*noise_speed)) / 20 ; // smooth pseudo random noise
// smooth_noise = sin_noise(ba.samp2sec(ba.time));

// noise_generator(i) = smooth_noise * g(i);


add_noise = case {
    (0) => _*0;
    (i) => sqrt(dt) * noise_generator(i);
};

noise = par(i,N,add_noise(i));



/* =========== Energy constraints ==============*/

strict_positivize(x) = max(ma.EPSILON, x);
constrain_to_positive = idle : par(i, N, strict_positivize(_)); // Energie levels have to be > 0
reset_source_sink(source, sink) = idle 
                                    <: ba.selector(0,N) * 0 + source, // E(0) is unchanged                        
                                    par(i, N-2, ba.selector(i+1,N)), 
                                    ba.selector(N-1,N) * 0 + sink; // E(N) is unchanged

constrain_output_to_positive = idle 
                               <: idle, constrain_to_positive
                               <: par(i, N, ba.if(checkbox("contrain output to positive values"), ba.selector(i+N, 2*N), ba.selector(i, 2*N)));


/* =========== Exciter ==============*/

exciter(excite) = idle
                    <: ba.selector(0,N), // source
                        par(i, N-2, (ba.selector(i+1,N), hslider("E%{i}", 0.1, 0, 1, 0.01) : _ * (1-excite), _ * excite :> _) ),
                        ba.selector(N-1,N); // sink


/* =========== Energy computation ==============*/

E(excite, source, sink) = idle
                            : constrain_to_positive
                            : exciter(excite)
                            <: idle, dissipate, transfer_from_lower, transfer_to_higher, noise
                            :> idle
                            : constrain_output_to_positive
                            : reset_source_sink(source, sink);

energy(excite, source, sink) = E(excite, source, sink) ~ idle; // feed back the energy output to itself


strip_source_sink = idle <: par(i, N-2, ba.selector(i+1,N)); // remove source and sink from output


safe_input(excite, source, sink) = ba.if(excite==0, 0, 1), strict_positivize(source), strict_positivize(sink);

// input: exciter (bool), source, sink
process = _, _, _ : safe_input : energy : strip_source_sink;

