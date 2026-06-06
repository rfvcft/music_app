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

// Function signature for freeing audio buffer
typedef _FreeAudioBuffer = ffi.Void Function(ffi.Pointer<ffi.Float> buffer);
typedef _FreeAudioBufferDart = void Function(ffi.Pointer<ffi.Float> buffer);

// Function signatures for audio buffer analysis
typedef _AnalyzeAudioBuffer = ffi.Pointer<CAudioAnalysisResult> Function(
		ffi.Pointer<ffi.Float> buffer, ffi.Int32 bufferLength);
typedef _AnalyzeAudioBufferDart = ffi.Pointer<CAudioAnalysisResult> Function(
		ffi.Pointer<ffi.Float> buffer, int bufferLength);

// Function signature for audio file analysis
typedef _AnalyzeAudioFile = ffi.Pointer<CAudioAnalysisResult> Function(
		ffi.Pointer<ffi.Char> filePath);
typedef _AnalyzeAudioFileDart = ffi.Pointer<CAudioAnalysisResult> Function(
		ffi.Pointer<ffi.Char> filePath);

// Function signature for deleting analysis result
typedef _DeleteAnalysisResult = ffi.Void Function(
		ffi.Pointer<CAudioAnalysisResult> result);
typedef _DeleteAnalysisResultDart = void Function(
		ffi.Pointer<CAudioAnalysisResult> result);

// Supported audio formats for iOS
List<String> supportedAudioFormatsIOS = ['wav', 'mp3', 'flac', 'm4a', 'aac', 'opus'];

// Supported audio formats for Android
List<String> supportedAudioFormatsAndroid = ['wav', 'mp3', 'flac'];

// Supported audio formats for C++ library dr_libs 
List<String> supportedAudioFormatsDRLIBS = ['wav', 'mp3', 'flac'];


/// Loads audio files to audio buffers. 
/// On iOS most audio files are supported (e.g. .wav, .mp3, .flac, .m4a, .aac, .opus). The class uses AVFoundation internally, compiled from Objective C.
/// Android is not implemented yet. Maybe we'll use ffmpeg, compiled from C++. 
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
  
/// Analyzes audio buffers and audio files using our custom library "audioanalysis". Direct file analysis uses internally "dr_libs" and works on .mp3, .wav or .flac only.
class AudioAnalysisFfi {
	static AudioAnalysisFfi? _cache;

	final ffi.DynamicLibrary _audioanalysisLib;

	late final _AnalyzeAudioBufferDart _analyzeAudioBuffer = _audioanalysisLib
		.lookupFunction<_AnalyzeAudioBuffer, _AnalyzeAudioBufferDart>('analyze_audio_buffer');
	late final _AnalyzeAudioFileDart _analyzeAudioFile = _audioanalysisLib
		.lookupFunction<_AnalyzeAudioFile, _AnalyzeAudioFileDart>('analyze_audio_file');
	late final _DeleteAnalysisResultDart _deleteAnalysisResult = _audioanalysisLib
		.lookupFunction<_DeleteAnalysisResult, _DeleteAnalysisResultDart>('delete_analysis_result');

	factory AudioAnalysisFfi() {
		if (Platform.isIOS) {
			_cache ??= AudioAnalysisFfi._internalIOS();
			return _cache!;
		} else if (Platform.isAndroid) {
			_cache ??= AudioAnalysisFfi._internalAndroid();
			return _cache!;
		} else {
			throw UnsupportedError('AudioAnalysisFfi only supports iOS and Android');
		}
	}

	AudioAnalysisFfi._internalIOS()
			: _audioanalysisLib = ffi.DynamicLibrary.process();

	AudioAnalysisFfi._internalAndroid()
			: _audioanalysisLib = ffi.DynamicLibrary.open('libaudioanalysis.so');

	bool supportsDirectFileAnalysis(String filePath) {
		final lastDotIndex = filePath.lastIndexOf('.');
		if (lastDotIndex == -1 || lastDotIndex == filePath.length - 1) {
			return false;
		}
		final extension = filePath.substring(lastDotIndex + 1).toLowerCase();
		return supportedAudioFormatsDRLIBS.contains(extension);
	}

	/// Analyzes an audio buffer and returns the analysis result pointer.
	ffi.Pointer<CAudioAnalysisResult> analyzeBuffer(ffi.Pointer<ffi.Float> bufferPtr, int length) {
		final resultPtr = _analyzeAudioBuffer(bufferPtr, length);
		if (resultPtr == ffi.Pointer<CAudioAnalysisResult>.fromAddress(0)) {
			throw Exception('Audio analysis failed');
		}
		return resultPtr;
	}

	/// Analyzes an audio file directly via dr_libs-backed capi function analyze_audio_file.
	ffi.Pointer<CAudioAnalysisResult> analyzeFile(String filePath) {
		if (!supportsDirectFileAnalysis(filePath)) {
			throw Exception('File is not supported');
		}
		final filePathCStr = filePath.toNativeUtf8().cast<ffi.Char>();
		try {
			final resultPtr = _analyzeAudioFile(filePathCStr);
			if (resultPtr == ffi.Pointer<CAudioAnalysisResult>.fromAddress(0)) {
				throw Exception('Audio analysis failed');
			}
			return resultPtr;
		} finally {
			calloc.free(filePathCStr);
		}
	}

	void freeResult(ffi.Pointer<CAudioAnalysisResult> resultPtr) {
		_deleteAnalysisResult(resultPtr);
	}
}

/// Loads audio file, analyzes it, converts the result to Dart types, and cleans up.
class AudioProcessingFfi {

	static AudioProcessingFfi? _cache;

	final AudioLoaderFfi? _audioLoader;
	final AudioAnalysisFfi _analyzer;

	factory AudioProcessingFfi({AudioLoaderFfi? audioLoader, AudioAnalysisFfi? analyzer}) {
		if (Platform.isIOS) {
			_cache ??= AudioProcessingFfi._internalIOS(
					audioLoader: audioLoader,
					analyzer: analyzer,
				);
			return _cache!;
		} else if (Platform.isAndroid) {
			_cache ??= AudioProcessingFfi._internalAndroid(
					analyzer: analyzer,
				);
			return _cache!;
		} else {
			throw UnsupportedError('AudioProcessingFfi only supports iOS and Android');
		}
	}

	AudioProcessingFfi._internalIOS({AudioLoaderFfi? audioLoader, AudioAnalysisFfi? analyzer})
			: _audioLoader = audioLoader ?? AudioLoaderFfi(),
				_analyzer = analyzer ?? AudioAnalysisFfi();

	AudioProcessingFfi._internalAndroid({AudioAnalysisFfi? analyzer})
			: _audioLoader = null,
				_analyzer = analyzer ?? AudioAnalysisFfi();

	/// Loads an audio file and analyzes it. Returns a Dart map with results.
  /// If the audio file is supported by dr_libs, we analyze it directly. Otherwise we load the audio buffer platform-specifically and analyze the buffer.
	Map<String, dynamic> loadAndAnalyze(String filePath) {
		ffi.Pointer<CAudioAnalysisResult>? resultPtr;
		ffi.Pointer<ffi.Float>? bufferPtr;
		final shouldAnalyzeFileDirectly = _analyzer.supportsDirectFileAnalysis(filePath); 

		if (Platform.isIOS) {
			if (shouldAnalyzeFileDirectly) {
				resultPtr = _analyzer.analyzeFile(filePath);
			} else { 
				// Load audio buffer
				final audio = _audioLoader!.loadAudio(filePath);
				bufferPtr = audio['bufferPtr'] as ffi.Pointer<ffi.Float>;
				final length = audio['length'] as int;

				// Analyze buffer
				resultPtr = _analyzer.analyzeBuffer(bufferPtr, length);
			}
		} else if (Platform.isAndroid) {
			if (!shouldAnalyzeFileDirectly) {
				throw Exception('File is not supported');
			}
			resultPtr = _analyzer.analyzeFile(filePath);
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
		_analyzer.freeResult(resultPtr);
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
