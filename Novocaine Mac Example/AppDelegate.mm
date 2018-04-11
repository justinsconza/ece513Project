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
    
    __block int dumpMatch = 10;
    __block int dumpCount = 1;

    // players
    __block int N = 512;                // block size
    __block int L = FILTER_LENGTH;      // filter length
    __block int D = 20;                 // delay amount
    __block float delta = 0.001;        // gradient step size
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
    
    
    
    
    
    __block int F = N+L-1;    // output filtered length
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
    __block int fillFlag = 0;
    
    float* overlap;
    overlap = (float*)malloc(N*sizeof(float));
    vDSP_vfill(&zeros, overlap, 1, N);
    
    float* h;
    h = (float*)malloc(L*sizeof(float));
//    vDSP_vfill(&zeros, h, 1, L);
    cblas_scopy(L, filterCoeffs, 1, h, 1);
    
    float* hEnd = h + L-1;
        
    [self.audioManager setOutputBlock:^(float *outData, UInt32 numFrames, UInt32 numChannels) {
        // wself.ringBuffer->FetchInterleavedData(outData, numFrames, numChannels);
        
        while(wself.ringBufferIn->NumUnreadFrames() >= N + D){
            
            //wself.ringBufferIn->FetchData(bufferInL, numFrames + D, 0, 1);
            //wself.ringBufferIn->SeekReadHeadPosition(-D);
            wself.ringBufferIn->FetchData(bufferInL, numFrames, 0, 1);
            
//            for(int i=0; i<numFrames; i++){
//                input[i] = bufferInL[i];
//                // input[i] = bufferInL[i+D];          // "future" samples
//                // inputDelayed[i] = bufferInL[i];     // current
//            }
            
            cblas_scopy(N, bufferInL, 1, input, 1);
            
            // ---------------------------------------------------------------------------- //
            // https://stackoverflow.com/questions/35233153/incorrect-results-with-vdsp-conv
            // comment at bottom of page explains the "inputPadded + L" in call to cblas_scopy
            // ---------------------------------------------------------------------------- //
            
            // checking to make sure this is a separate branch...
            
            cblas_scopy(N, input, 1, inputPadded + L, 1);                           // pad input for convolution
            vDSP_conv(inputPadded, 1, hEnd, -1, convolutionOutput, 1, N+L-1, L);    // convolution
            vDSP_vadd(convolutionOutput, 1, overlap, 1, bufferOutL, 1, N);          // overlap add into output buffer
            cblas_scopy(L-1, convolutionOutput + N, 1, overlap, 1);                 // store overlap for next time

            cblas_scopy(N, bufferOutL, 1, reInterleaved, 2);                        // reinterleaved left channel
            cblas_scopy(N, bufferOutL, 1, reInterleaved+1, 2);                      // reinterleaved right channel
            
            /*
            if(fillFlag < 2){
                for(int i=0; i<N+L-1; i++){
                    convolutionOutputTimesTwo[fillFlag*(N+L-1) + i] = convolutionOutput[i];
                }
                fillFlag++;
            }

            if(fillFlag == 2)
                writeOutput(convolutionOutputTimesTwo, 2*(N+L-1), 44100);
            */
            
            
            if(dumpCount++ == dumpMatch)
                writeOutput(convolutionOutput, F, 44100);
            
            wself.ringBufferOut->AddNewInterleavedFloatData(reInterleaved, numFrames, numChannels);
            
        } // end while loop
        
        wself.ringBufferOut->FetchInterleavedData(outData, numFrames, numChannels);
        
    }];
    
    
    // START IT UP YO
    [self.audioManager play];
}

@end
