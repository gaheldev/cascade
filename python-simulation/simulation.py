from random import gauss
import numpy as np
import matplotlib.pyplot as plt
import csv



class Energy:
    def __init__(self, max_iter=1000, levels=[1,0.1,0.1,0.1,1], delta_t=0.1):
        self.max_iter = max_iter
        self.scale = len(levels)-2
        self._N = self.scale+1
        self.iteration = 0
        self.levels = levels

        self.delta_t = delta_t

        self.nu = 1
        self.k0 = 1
        self.lmda = 1.5
        self.alpha = 0.1
        self.beta = 0.1
        self.a = 1
        self.b =1
        self.eta = 1

        self.delta = 1/2
        self.gamma = 5/4


    def k(self,i):
        return self.k0 * (self.lmda ** (i+1))


    def dissipation(self,i):
        if i==0 or i==self._N:
            return 0
        return -self.nu * (self.k(i)**2) * self.levels[i]


    def f(self,i,x):
        if x == 0:
            return 0
        return self.a / (x**self.alpha * (1 + (self.a/self.b) * x**(self.beta-self.alpha)))

        
    def T(self, i):
        e_from = self.levels[i-1]
        e_to = self.levels[i]
        if e_from == 0:
            return 0
        return self.k(i) * (e_to**1.5) * self.f(i, e_to/e_from)


    def noise(self,i):
        return gauss() / (self.delta_t ** 0.5)


    def g(self,i):
        return self.eta * self.k(i)**self.delta * self.levels[i]**self.gamma
        

    def next_level(self, n):
        if n==0 or n==self._N:
            return self.levels[n]
        e = self.levels[n] + self.delta_t * (  self.dissipation(n)
                                             + self.T(n)
                                             - self.T(n+1)
                                             + self.g(n)*self.noise(n)
                                            )
        e = max(e,0)
        return e
            

    def __iter__(self):
        yield self.levels
        i = 0
        while True:
            self.levels = [self.next_level(i) for i in range(self._N+1)]
            yield self.levels
            i += 1
            if i > self.max_iter:
                return

        

initial_values = [1,0.1,0.1,0.1,1]
# initial_values = [1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,1]

N = 1000
energy = Energy(max_iter=N, levels=initial_values, delta_t=0.001)
energy.k0 = 0.3
energy.alpha = 0.1
energy.beta = 0.93
energy.lmda = 1.08
energy.eta = 0


# N = 200
# for i, levels in enumerate(energy):
#     print(levels)
#     if i >= N:
#         break

e = np.asarray([levels for levels in energy])

np.savetxt("simu.csv", e, delimiter=",")

plt.plot(e)
plt.show()
