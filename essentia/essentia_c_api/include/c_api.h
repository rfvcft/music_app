#pragma once

#ifdef __cplusplus
extern "C" {
#endif


void essentia_init();
void essentia_shutdown();

// Analysis result struct for FFI (chromagram is row-major: chromagram[i * chroma_n_bins + j])
typedef struct {
	char* key;            // C string (must be freed)
	float duration;       // Duration in seconds
	float* chromagram;    // Flat array, size: n_frames * n_bins (must be freed)
	int chroma_n_frames;  // Number of frames (rows)
	int chroma_n_bins;    // Number of bins (columns)
} EssentiaAnalysisResult;

// Analyze a float* buffer and return all results. Must be freed with delete_analysis_result.
EssentiaAnalysisResult* essentia_analyze_buffer(const float* buffer, int buffer_length);

// Free an EssentiaAnalysisResult and all its heap-allocated fields
void delete_analysis_result(EssentiaAnalysisResult* result);

#ifdef __cplusplus
}
#endif