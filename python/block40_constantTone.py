import numpy as np
import scipy as sp

import matplotlib
import matplotlib.pyplot as plt

F_s = 44100

output = np.array([

    0.00001796222932171077,
    0.00001833038004406262,
    0.00001846273335104343,
    0.00001830153087212238,
    0.00001790424357750453,
    0.00001739878098305780,
    0.00001690591307124123,
    0.00001648727084102575,
    0.00001614297070773318,
    0.00001585376230650581,
    0.00001562037687108386,
    0.00001546738531033043,
    0.00001541784149594605,
    0.00001546271232655272,
    0.00001554604750708677,
    0.00001558301300974563,
    0.00001549705302750226,
    0.00001525256902823457,
    0.00001486920155002736,
    0.00001440565392840654,
    0.00001392708327330183,
    0.00001347282159258612,
    0.00001304463239648612,
    0.00001262873047380708,
    0.00001222531500388868,
    0.00001185925339086680,
    0.00001156521739176242,
    0.00001135144793806830,
    0.00001117877945944201,
    0.00001097834319807589,
    0.00001068815890903352,
    0.00001028908172884258,
])

plt.plot(output)