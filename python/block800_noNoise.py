import numpy as np
import scipy as sp

import matplotlib
import matplotlib.pyplot as plt

F_s = 44100

output = np.array([

    0.00000155479847308015,
    0.00000161853313329630,
    0.00000163978722866887,
    0.00000161794764608203,
    0.00000155365285081643,
    0.00000144866714890668,
    0.00000130583850932453,
    0.00000112898533188854,
    0.00000092273597829262,
    0.00000069250256728992,
    0.00000044433534185373,
    0.00000018473343743608,
    -0.00000007946151470151,
    -0.00000034128672155020,
    -0.00000059386991324573,
    -0.00000083060331235174,
    -0.00000104534046840854,
    -0.00000123256972983654,
    -0.00000138749510369962,
    -0.00000150616028804507,
    -0.00000158556224505446,
    -0.00000162363687650213,
    -0.00000161942125487258,
    -0.00000157298927661031,
    -0.00000148550429912575,
    -0.00000135929042244243,
    -0.00000119764047212811,
    -0.00000100482850484696,
    -0.00000078597582842121,
    -0.00000054678366723238,
    -0.00000029347535246416,
    -0.00000003263465941927,
])

plt.plot(output)