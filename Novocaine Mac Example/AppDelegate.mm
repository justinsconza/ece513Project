// Copyright (c) 2012 Alex Wiltschko
// 
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


#import "AppDelegate.h"

@implementation AppDelegate

- (void)dealloc
{
    if (_ringBufferIn){
        delete _ringBufferIn;
    }
    if (_ringBufferOut){
        delete _ringBufferOut;
    }
    if (_ringBufferOverlap){
        delete _ringBufferOverlap;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    self.audioManager = [Novocaine audioManager];
    
    int ringBufferLength = 32*512;
    self.ringBufferIn = new RingBuffer(ringBufferLength, 2);
    self.ringBufferOut = new RingBuffer(ringBufferLength, 2);
    self.ringBufferOverlap = new RingBuffer(512, 2);
    
    __weak AppDelegate * wself = self;
    
    __block int dumpMatch = 100;
    __block int dumpCount = 1;

    // players
    __block int N = 512;                // block size
    __block int L = 32;                 // filter length
    __block int D = 100;                 // delay amount
    __block float delta = 0.000001;        // gradient step size
    __block float zeros = 0.0;          // for filling arrays
    
    // from 1024 containing both channels at once to two arrays of 512 for L and R separate
    float* deInterleavedL;
    float* deInterleavedR;
    deInterleavedL = new float[N];
    deInterleavedR = new float[N];
    for(int i=0; i<N; i++){
        deInterleavedL[i] = deInterleavedR[i] = 0.0;
    }
    
    // 1024 length
    float* reInterleaved;
    reInterleaved = new float[2*N];
    for(int i=0; i<2*N; i++){
        reInterleaved[i] = 0.0;
    }
    
    
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        // wself.ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
        
        for(int i=0; i<numFrames; i++){
            deInterleavedL[i] = data[2*i];
        }
        
        wself.ringBufferIn->AddNewFloatData(deInterleavedL, numFrames, 0);
        
    }];
    
    // ---- i/o related arrays ----- //
    
    float* bufferInL;
    bufferInL = (float*)malloc((N+D)*sizeof(float));
    vDSP_vfill(&zeros, bufferInL, 1, N+D);
    
    float* bufferInR;
    bufferInR = (float*)malloc((N+D)*sizeof(float));
    vDSP_vfill(&zeros, bufferInR, 1, N+D);
    
    float* bufferOutL;
    bufferOutL = (float*)malloc(N*sizeof(float));
    vDSP_vfill(&zeros, bufferOutL, 1, N);
    
    float* bufferOutR;
    bufferOutR = (float*)malloc(N*sizeof(float));
    vDSP_vfill(&zeros, bufferOutR, 1, N);
    
    float* input;
    input = (float*)malloc(N*sizeof(float));
    vDSP_vfill(&zeros, input, 1, N);
    
    float* inputDelayed;
    inputDelayed = (float*)malloc(N*sizeof(float));
    vDSP_vfill(&zeros, inputDelayed, 1, N);
    
    
    
    // ---- filter related arrays ----- //
    
    __block int F = N+L-1;                          // output filtered length
    __block int P = (L+3 & -4u) + N+L-1;//N+L-1;    // length of padded signal passed to vDSP_conv comes to 1023
    
    float* inputPadded;
    inputPadded = (float*)malloc(P*sizeof(float));
    vDSP_vfill(&zeros, inputPadded, 1, P);
    
    float* convolutionOutput;
    convolutionOutput = (float*)malloc(F*sizeof(float));
    vDSP_vfill(&zeros, convolutionOutput, 1, F);
    
    float* convolutionOutputTimesTwo;
    convolutionOutputTimesTwo = (float*)malloc(2*F*sizeof(float));
    vDSP_vfill(&zeros, convolutionOutputTimesTwo, 1, 2*F);
    
    float* overlap;
    overlap = (float*)malloc(N*sizeof(float));
    vDSP_vfill(&zeros, overlap, 1, N);
    
    float* hNew;
    hNew = (float*)malloc(L*sizeof(float));
    vDSP_vfill(&zeros, hNew, 1, L);
    
    float* hOld;
    hOld = (float*)malloc(L*sizeof(float));
    vDSP_vfill(&zeros, hOld, 1, L);
    
    
    // ---- wiener related arrays ----- //
    
    __block float scale = N-L;          // for scaling filter average at end
    
    float* error;
    error = (float*)malloc(N*sizeof(float));
    vDSP_vfill(&zeros, error, 1, N);
    
    float* gradient;
    gradient = (float*)malloc(L*sizeof(float));
    vDSP_vfill(&zeros, gradient, 1, L);
    
    float* delayedBlock;
    delayedBlock = (float*)malloc(L*sizeof(float));
    vDSP_vfill(&zeros, delayedBlock, 1, L);
    
    
    // ----- recording output -------- //
    __block int nRecord = 0;
    __block int recordStart = 15*N;
    __block int recordStop = recordStart+30*N;
    float* recording;
    recording = (float*)malloc((recordStop-recordStart) * sizeof(float));
    
    [self.audioManager setOutputBlock:^(float *outData, UInt32 numFrames, UInt32 numChannels) {
        // wself.ringBuffer->FetchInterleavedData(outData, numFrames, numChannels);
        
        while(wself.ringBufferIn->NumUnreadFrames() >= N + D){
            
            wself.ringBufferIn->FetchData(bufferInL, numFrames + D, 0, 1);
            wself.ringBufferIn->SeekReadHeadPosition(-D);
            
            
            
            cblas_scopy(N, bufferInL+D, 1, input, 1);         // current
            cblas_scopy(N, bufferInL, 1, inputDelayed, 1);    // "past"
            
            // -------- do the actual filtering ------------------------------------------- //
            
            cblas_scopy(N, inputDelayed, 1, inputPadded + L, 1);                        // pad input for convolution
            vDSP_conv(inputPadded, 1, hNew+L-1, -1, convolutionOutput, 1, N+L-1, L);    // convolution
            vDSP_vadd(convolutionOutput, 1, overlap, 1, bufferOutL, 1, N);              // overlap add into output buffer
            cblas_scopy(L-1, convolutionOutput + N, 1, overlap, 1);                     // store overlap for next time
            
            
//            if(dumpCount++ == dumpMatch)
//                writeOutput(bufferOutL, N, 44100);
            
            // -------- do the wiener update stuff --------------------------------------- //
            
            vDSP_vsub(bufferOutL, 1, input, 1, error, 1, N);                    // error = input - filter output
            vDSP_vfill(&zeros, gradient, 1, L);
            
            for(int i=0; i<N-L; i++){
                cblas_scopy(L, inputDelayed + i, 1, delayedBlock, 1);           // delayedBlock = inputDelayed[i:i+L]
                vDSP_vsmul(delayedBlock, 1, &error[i], delayedBlock, 1, L);     // error[i]*delayedBlock
                vDSP_vadd(gradient, 1, delayedBlock, 1, gradient, 1, L);        // gradient += error[i]*delayedBlock
            }

            vDSP_vsmul(gradient, 1, &scale, gradient, 1, L);                    // gradient /= (len(delayedBlock)-L)
            vDSP_vsmul(gradient, 1, &delta, gradient, 1, L);                    // gradient *= delta
            vDSP_vadd(hOld, 1, gradient, 1, hNew, 1, L);
            
            // -------- prep for output -------------------------------------------------- //
            
            cblas_scopy(N, bufferOutL, 1, reInterleaved, 2);                            // reinterleaved left channel
            cblas_scopy(N, bufferOutL, 1, reInterleaved+1, 2);                          // reinterleaved right channel
            
            /*
            if(nRecord >= recordStart & nRecord < recordStop ) {
                cblas_scopy(N, bufferOutL, 1, recording + (nRecord-recordStart), 1);
                printf("%d\n",nRecord);
            }
            
            if(nRecord == recordStop) {
                writeOutput(recording, recordStop - recordStart, 44100);
                printf("done recording\n");
            }
            nRecord+=N;
            */
            
            
            wself.ringBufferOut->AddNewInterleavedFloatData(reInterleaved, numFrames, numChannels);
            
        } // end while loop
        
        wself.ringBufferOut->FetchInterleavedData(outData, numFrames, numChannels);
        
    }];
    
    
    // START IT UP YO
    [self.audioManager play];
}

@end
