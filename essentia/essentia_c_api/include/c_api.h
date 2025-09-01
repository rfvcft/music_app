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
	float* chromagram;    // Flat array, size: n_frames * n_bins
	int chroma_n_frames;  // Number of frames (rows)
	int chroma_n_bins;    // Number of bins (columns)
} EssentiaAnalysisResult;

// Analyze a float* buffer and return all results. Must be freed with delete_analysis_result.
EssentiaAnalysisResult* essentia_analyze_buffer(const float* buffer, int buffer_length);

// Free an EssentiaAnalysisResult and all its heap-allocated fields
void delete_analysis_result(EssentiaAnalysisResult* result);

// Computes the key from a raw float32 audio file. Returns a newly allocated C string (must be freed with delete_c_string)
const char* compute_key_from_file(const char* file_path);

// Computes the key from a float* buffer and its length. Returns a newly allocated C string (must be freed with delete_c_string)
const char* compute_key_from_float_buffer(const float* buffer, int length);

// Frees a C string allocated by compute_key_from_file
void delete_c_string(char* str);

#ifdef __cplusplus
}
#endif