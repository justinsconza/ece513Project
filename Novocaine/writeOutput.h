//
//  writeOutput.h
//  Novocaine
//
//  Created by Justin Sconza on 3/24/18.
//  Copyright © 2018 Datta Lab, Harvard University. All rights reserved.
//

#ifndef writeOutput_h
#define writeOutput_h

void writeOutput(float* output, int length, int FS, NSString* name) {
    
    NSString* pathAndName = [NSString stringWithFormat:@"%@%@", @"/Users/justinsconza/Documents/coreAudio/ece513_babySteps/python/", name];
    const char* fileToOpen = [pathAndName UTF8String];
    FILE* f = fopen(fileToOpen, "w+");
    
    // FILE* f = fopen("/Users/justinsconza/Documents/coreAudio/ece513_babySteps/python/output.py", "w+");
    
    fputs("import numpy as np\n",f);
    fputs("import scipy as sp\n\n",f);
    
    fputs("import matplotlib\n",f);
    fputs("import matplotlib.pyplot as plt\n\n",f);
    
    fprintf(f, "F_s = %d\n\n", FS);
    
    fputs("output = np.array([\n\n",f);
    for(int i=0; i<length; i++){
        
        fprintf(f, "    %.20f,\n",output[i]);
    }
    fputs("])\n\n",f);
    
    fputs("plt.plot(output)",f);
    
    fclose(f);
    
}

#endif /* writeOutput_h */
