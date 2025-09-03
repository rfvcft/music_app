
#import <AVFoundation/AVFoundation.h>
#include <vector>
#include <stdlib.h>

extern "C" {
// Loads an audio file at filePath, converts to mono, 44.1kHz, float32, and returns a malloc'd buffer. Length is set in outLength.
float* loadAudioBufferFromM4A(const char* filePath, int* outLength) {
	@autoreleasepool {
		NSString* nsPath = [NSString stringWithUTF8String:filePath];
		NSURL* url = [NSURL fileURLWithPath:nsPath];
		NSError* error = nil;
		AVAudioFile* audioFile = [[AVAudioFile alloc] initForReading:url error:&error];
		if (error || !audioFile) {
			*outLength = 0;
			return nullptr;
		}

		// Set up format: mono, 44.1kHz, float32
		AVAudioFormat* desiredFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
																	   sampleRate:44100.0
																		 channels:1
																	  interleaved:NO];
		AVAudioPCMBuffer* pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:desiredFormat frameCapacity:(AVAudioFrameCount)audioFile.length];
		AVAudioConverter* converter = [[AVAudioConverter alloc] initFromFormat:audioFile.processingFormat toFormat:desiredFormat];
		AVAudioPCMBuffer* tempBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFile.processingFormat frameCapacity:(AVAudioFrameCount)audioFile.length];
		[audioFile readIntoBuffer:tempBuffer error:&error];
		if (error) {
			*outLength = 0;
			return nullptr;
		}

		AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer *(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus) {
			*outStatus = AVAudioConverterInputStatus_HaveData;
			return tempBuffer;
		};
		[converter convertToBuffer:pcmBuffer error:&error withInputFromBlock:inputBlock];
		if (error) {
			*outLength = 0;
			return nullptr;
		}

		float* floatData = pcmBuffer.floatChannelData[0];
		int length = (int)pcmBuffer.frameLength;
		float* outBuffer = (float*)malloc(sizeof(float) * length);
		memcpy(outBuffer, floatData, sizeof(float) * length);
		*outLength = length;
		return outBuffer;
	}
}

// Free the buffer allocated by loadAudioBufferFromM4A
void freeAudioBuffer(float* buffer) {
	free(buffer);
}
}
