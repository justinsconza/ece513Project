import numpy as np
import scipy as sp

import matplotlib
import matplotlib.pyplot as plt

F_s = 44100

output = np.array([

    0.00000013811661858654,
    0.00000015008198772648,
    0.00000015433701605616,
    0.00000015050522961246,
    0.00000013882879557059,
    0.00000012002763583041,
    0.00000009517653865032,
    0.00000006563381305114,
    0.00000003286849192818,
    -0.00000000156183210809,
    -0.00000003602509934808,
    -0.00000006884787495665,
    -0.00000009837622627629,
    -0.00000012308633756675,
    -0.00000014168121253988,
    -0.00000015316534529575,
    -0.00000015694325838922,
    -0.00000015285920085262,
    -0.00000014117837565664,
    -0.00000012252962733328,
    -0.00000009783519772100,
    -0.00000006829411347553,
    -0.00000003532906234227,
    -0.00000000052974802323,
    0.00000003443054197305,
    0.00000006784433992379,
    0.00000009805408751618,
    0.00000012356265699509,
    0.00000014307190099316,
    0.00000015557994004212,
    0.00000016043615858052,
    0.00000015734111968868,
])

plt.plot(output)