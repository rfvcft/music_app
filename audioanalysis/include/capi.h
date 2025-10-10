#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Analysis result struct for FFI 
// The chromaMatrix, computed by AudioAnalyzer, is flattened to chromagram according to chromaMatrix[frame][bin] = chromagram[bin * chroma_n_frames + frame]
typedef struct {
	char* key;            // C string (must be freed)
	float duration;       // Duration in seconds
	float* chromagram;    // Flat array, size: n_frames * n_bins (must be freed)
	int chroma_n_frames;  // Number of frames
	int chroma_n_bins;    // Number of bins
} CAudioAnalysisResult;

// Analyze a float* buffer and return results. Must be freed with delete_analysis_result.
CAudioAnalysisResult* analyze_audio_buffer(const float* buffer, int buffer_length);

// Free an CAudioAnalysisResult and all its heap-allocated fields
void delete_analysis_result(CAudioAnalysisResult* result);

#ifdef __cplusplus
}
#endif