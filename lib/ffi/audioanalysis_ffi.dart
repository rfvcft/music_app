import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// C struct mapping for CAudioAnalysisResult from audioanalysis/include/capi.h
@ffi.Packed(8)
final class CAudioAnalysisResult extends ffi.Struct {
	external ffi.Pointer<ffi.Char> key;
	@ffi.Float()
	external double duration;
	external ffi.Pointer<ffi.Float> chromagram;
	@ffi.Int32()
	external int chroma_n_frames;
	@ffi.Int32()
	external int chroma_n_bins;
}


// Function signatures for loading audio (generic file)
typedef _LoadAudioBufferFromFile = ffi.Pointer<ffi.Float> Function(
	ffi.Pointer<ffi.Char> filePath, ffi.Pointer<ffi.Int32> outLength);
typedef _LoadAudioBufferFromFileDart = ffi.Pointer<ffi.Float> Function(
	ffi.Pointer<ffi.Char> filePath, ffi.Pointer<ffi.Int32> outLength);

typedef _FreeAudioBuffer = ffi.Void Function(ffi.Pointer<ffi.Float> buffer);
typedef _FreeAudioBufferDart = void Function(ffi.Pointer<ffi.Float> buffer);

// Function signatures for audio analysis
typedef _AnalyzeAudioBuffer = ffi.Pointer<CAudioAnalysisResult> Function(
		ffi.Pointer<ffi.Float> buffer, ffi.Int32 bufferLength);
typedef _AnalyzeAudioBufferDart = ffi.Pointer<CAudioAnalysisResult> Function(
		ffi.Pointer<ffi.Float> buffer, int bufferLength);

// Android signature for direct file analysis
typedef _AnalyzeAudioFile = ffi.Pointer<CAudioAnalysisResult> Function(
		ffi.Pointer<ffi.Char> filePath);

typedef _DeleteAnalysisResult = ffi.Void Function(
		ffi.Pointer<CAudioAnalysisResult> result);
typedef _DeleteAnalysisResultDart = void Function(
		ffi.Pointer<CAudioAnalysisResult> result);


/// Loads audio files to audio buffer (on iOS, .wav, .m4a, .mp3 are supported)
class AudioLoaderFfi {
	late final ffi.DynamicLibrary _audioLoaderLib = _loadLibrary();
	late final _LoadAudioBufferFromFileDart loadAudioBufferFromFile = _audioLoaderLib
			.lookupFunction<_LoadAudioBufferFromFile, _LoadAudioBufferFromFileDart>('loadAudioBufferFromFile');
	late final _FreeAudioBufferDart freeAudioBuffer = _audioLoaderLib
			.lookupFunction<_FreeAudioBuffer, _FreeAudioBufferDart>('freeAudioBuffer');

	AudioLoaderFfi();

	static ffi.DynamicLibrary _loadLibrary() {
		if (Platform.isIOS) {
			// On iOS, use process() to access symbols from the main app binary
			return ffi.DynamicLibrary.process();
		} else if (Platform.isAndroid) {
			// Android not implemented yet
			throw UnimplementedError('AudioLoaderFfi is not implemented for Android');
		} else {
			throw UnsupportedError('AudioLoaderFfi only supports iOS and Android');
		}
	}

	/// Loads an audio file and returns a pointer to the buffer and its length.
	Map<String, dynamic> loadAudio(String filePath) {
		final filePathPtr = filePath.toNativeUtf8().cast<ffi.Char>();
		final outLengthPtr = calloc<ffi.Int32>();
		try {
			final bufferPtr = loadAudioBufferFromFile(filePathPtr, outLengthPtr);
			final length = outLengthPtr.value;
			if (bufferPtr == ffi.Pointer<ffi.Float>.fromAddress(0) || length == 0) {
				throw Exception('Failed to load audio buffer');
			}
			return {
				'bufferPtr': bufferPtr,
				'length': length,
			};
		} finally {
			calloc.free(filePathPtr);
			calloc.free(outLengthPtr);
		}
	}
}
  
/// Analyzes audio buffers using our custom library "audioanalysis"
class AudioAnalysisFfi {
	late final ffi.DynamicLibrary _audioanalysisLib = _loadLibrary();
	late final _AnalyzeAudioBufferDart analyzeAudioBuffer = _audioanalysisLib
		.lookupFunction<_AnalyzeAudioBuffer, _AnalyzeAudioBufferDart>('analyze_audio_buffer');
	late final _DeleteAnalysisResultDart deleteAnalysisResult = _audioanalysisLib
		.lookupFunction<_DeleteAnalysisResult, _DeleteAnalysisResultDart>('delete_analysis_result');

	AudioAnalysisFfi();

	static ffi.DynamicLibrary _loadLibrary() {
		if (Platform.isIOS) {
			return ffi.DynamicLibrary.process();
		} else if (Platform.isAndroid) {
			throw UnimplementedError('AudioAnalysisFfi is not implemented for Android');
		} else {
			throw UnsupportedError('AudioAnalysisFfi only supports iOS and Android');
		}
	}

	/// Analyzes an audio buffer and returns the analysis result pointer.
	ffi.Pointer<CAudioAnalysisResult> analyzeBuffer(ffi.Pointer<ffi.Float> bufferPtr, int length) {
		final resultPtr = analyzeAudioBuffer(bufferPtr, length);
		if (resultPtr == ffi.Pointer<CAudioAnalysisResult>.fromAddress(0)) {
			throw Exception('Audio analysis failed');
		}
		return resultPtr;
	}

	void freeResult(ffi.Pointer<CAudioAnalysisResult> resultPtr) {
		deleteAnalysisResult(resultPtr);
	}
}

/// Loads audio file, analyzes it, converts the result to Dart types, and cleans up.
class AudioProcessingFfi {

	static AudioProcessingFfi? _cache;

	// for iOS
	final AudioLoaderFfi? _audioLoader;
	final AudioAnalysisFfi? _analyzer;

	// for Android
	late final _AnalyzeAudioFile? _analyzeAudioFile;
	late final _DeleteAnalysisResultDart? _deleteAnalysisResult;

	factory AudioProcessingFfi({AudioLoaderFfi? audioLoader, AudioAnalysisFfi? analyzer}) {
		if (Platform.isIOS) {
			_cache ??= AudioProcessingFfi._internalIOS(
					audioLoader: audioLoader,
					analyzer: analyzer,
				);
			return _cache!;
		} else if (Platform.isAndroid) {
			_cache ??= AudioProcessingFfi._internalAndroid();
			return _cache!;
		} else {
			throw UnsupportedError('AudioProcessingFfi only supports iOS and Android');
		}
	}

	AudioProcessingFfi._internalIOS({AudioLoaderFfi? audioLoader, AudioAnalysisFfi? analyzer})
			: _audioLoader = audioLoader ?? AudioLoaderFfi(),
				_analyzer = analyzer ?? AudioAnalysisFfi(),
				_analyzeAudioFile = null;

	AudioProcessingFfi._internalAndroid()
			: _audioLoader = null,
				_analyzer = null {
		final ffi.DynamicLibrary audioanalysis = ffi.DynamicLibrary.open('libaudioanalysis.so');
		_analyzeAudioFile = audioanalysis
				.lookupFunction<_AnalyzeAudioFile, _AnalyzeAudioFile>("analyze_audio_file");
		_deleteAnalysisResult = audioanalysis
				.lookupFunction<_DeleteAnalysisResult, _DeleteAnalysisResultDart>("delete_analysis_result");
	}

	/// Loads an audio file and analyzes it. Returns a Dart map with results.
	Map<String, dynamic> loadAndAnalyze(String filePath) {
		ffi.Pointer<CAudioAnalysisResult>? resultPtr;
		ffi.Pointer<ffi.Float>? bufferPtr;
		if (Platform.isIOS) {
			// Load audio buffer
			final audio = _audioLoader!.loadAudio(filePath);
			bufferPtr = audio['bufferPtr'] as ffi.Pointer<ffi.Float>;
			final length = audio['length'] as int;

			// Analyze buffer
			resultPtr = _analyzer!.analyzeBuffer(bufferPtr, length);
		} else if (Platform.isAndroid) {
			final filePathCStr = filePath.toNativeUtf8().cast<ffi.Char>();
			try {
				resultPtr = _analyzeAudioFile!(filePathCStr);
			} finally {
				calloc.free(filePathCStr);
			}
		}
		if (resultPtr == null) {
			throw Exception('Audio analysis failed');
		}
		final result = resultPtr.ref;

    // Convert C types to Dart types
		final key = result.key == ffi.Pointer<ffi.Char>.fromAddress(0)
				? ''
				: result.key.cast<Utf8>().toDartString();
		final duration = result.duration;
    
    // Unflatten 1D chromagram
		final chromaFrames = result.chroma_n_frames;
		final chromaBins = result.chroma_n_bins;
		List<List<double>>? chromagram;
		if (result.chromagram != ffi.Pointer<ffi.Float>.fromAddress(0) &&
				chromaFrames > 0 &&
				chromaBins > 0) {
			final flat = result.chromagram
					.asTypedList(chromaFrames * chromaBins)
					.map((e) => e.toDouble())
					.toList();
			chromagram = List.generate(
				chromaBins,
				(bin) => List.generate(
					chromaFrames,
					(frame) => flat[bin * chromaFrames + frame],
				),
			);
		}

		// Clean up
		if (Platform.isIOS) {
			_analyzer!.deleteAnalysisResult(resultPtr);
		} else if (Platform.isAndroid) {
			_deleteAnalysisResult!(resultPtr);
		}
		if (bufferPtr != null) {
			_audioLoader?.freeAudioBuffer(bufferPtr);
		}

		return {
			'key': key,
			'duration': duration,
			'chromagram': chromagram,
		};
	}
}
