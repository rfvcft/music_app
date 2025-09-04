import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// C struct mapping for EssentiaAnalysisResult from essentia/essentia_c_api/c_api.h
@ffi.Packed(8)
final class EssentiaAnalysisResult extends ffi.Struct {
	external ffi.Pointer<ffi.Char> key;
	@ffi.Float()
	external double duration;
	external ffi.Pointer<ffi.Float> chromagram;
	@ffi.Int32()
	external int chroma_n_frames;
	@ffi.Int32()
	external int chroma_n_bins;
}


typedef _LoadAudioBufferFromM4A = ffi.Pointer<ffi.Float> Function(
		ffi.Pointer<ffi.Char> filePath, ffi.Pointer<ffi.Int32> outLength);
typedef _LoadAudioBufferFromM4ADart = ffi.Pointer<ffi.Float> Function(
		ffi.Pointer<ffi.Char> filePath, ffi.Pointer<ffi.Int32> outLength);

typedef _FreeAudioBuffer = ffi.Void Function(ffi.Pointer<ffi.Float> buffer);
typedef _FreeAudioBufferDart = void Function(ffi.Pointer<ffi.Float> buffer);

typedef _EssentiaAnalyzeBuffer = ffi.Pointer<EssentiaAnalysisResult> Function(
		ffi.Pointer<ffi.Float> buffer, ffi.Int32 bufferLength);
typedef _EssentiaAnalyzeBufferDart = ffi.Pointer<EssentiaAnalysisResult> Function(
		ffi.Pointer<ffi.Float> buffer, int bufferLength);

typedef _DeleteAnalysisResult = ffi.Void Function(
		ffi.Pointer<EssentiaAnalysisResult> result);
typedef _DeleteAnalysisResultDart = void Function(
		ffi.Pointer<EssentiaAnalysisResult> result);

class AudioLoaderFfi {

	late final ffi.DynamicLibrary _audioLoaderLib = _loadLibrary();
	late final _LoadAudioBufferFromM4ADart loadAudioBufferFromM4A = _audioLoaderLib
			.lookupFunction<_LoadAudioBufferFromM4A, _LoadAudioBufferFromM4ADart>('loadAudioBufferFromM4A');
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

	/// Loads an .m4a file and returns a pointer to the buffer and its length.
	Map<String, dynamic> loadAudio(String filePath) {
		final filePathPtr = filePath.toNativeUtf8().cast<ffi.Char>();
		final outLengthPtr = calloc<ffi.Int32>();
		try {
			final bufferPtr = loadAudioBufferFromM4A(filePathPtr, outLengthPtr);
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

class EssentiaAnalyzerFfi {
	late final ffi.DynamicLibrary _essentiaLib = _loadLibrary();
	late final _EssentiaAnalyzeBufferDart essentiaAnalyzeBuffer = _essentiaLib
		.lookupFunction<_EssentiaAnalyzeBuffer, _EssentiaAnalyzeBufferDart>('essentia_analyze_buffer');
	late final _DeleteAnalysisResultDart deleteAnalysisResult = _essentiaLib
		.lookupFunction<_DeleteAnalysisResult, _DeleteAnalysisResultDart>('delete_analysis_result');

	EssentiaAnalyzerFfi();

	static ffi.DynamicLibrary _loadLibrary() {
		if (Platform.isIOS) {
			return ffi.DynamicLibrary.process();
		} else if (Platform.isAndroid) {
			throw UnimplementedError('EssentiaAnalyzerFfi is not implemented for Android');
		} else {
			throw UnsupportedError('EssentiaAnalyzerFfi only supports iOS and Android');
		}
	}

	/// Analyzes an audio buffer and returns the analysis result pointer.
	ffi.Pointer<EssentiaAnalysisResult> analyzeBuffer(ffi.Pointer<ffi.Float> bufferPtr, int length) {
		final resultPtr = essentiaAnalyzeBuffer(bufferPtr, length);
		if (resultPtr == ffi.Pointer<EssentiaAnalysisResult>.fromAddress(0)) {
			throw Exception('Essentia analysis failed');
		}
		return resultPtr;
	}

	void freeResult(ffi.Pointer<EssentiaAnalysisResult> resultPtr) {
		deleteAnalysisResult(resultPtr);
	}
}

class AudioProcessingFfi {
	final AudioLoaderFfi audioLoader;
	final EssentiaAnalyzerFfi analyzer;

	AudioProcessingFfi({AudioLoaderFfi? audioLoader, EssentiaAnalyzerFfi? analyzer})
			: audioLoader = audioLoader ?? AudioLoaderFfi(),
				analyzer = analyzer ?? EssentiaAnalyzerFfi();

	/// Loads an .m4a file and analyzes it with Essentia. Returns a Dart map with results.
	Map<String, dynamic> loadAndAnalyze(String filePath) {
    // Load audio buffer
		final audio = audioLoader.loadAudio(filePath);
		final bufferPtr = audio['bufferPtr'] as ffi.Pointer<ffi.Float>;
		final length = audio['length'] as int;

    // Analyze buffer
		final resultPtr = analyzer.analyzeBuffer(bufferPtr, length);
		final result = resultPtr.ref;
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
		analyzer.freeResult(resultPtr);
		audioLoader.freeAudioBuffer(bufferPtr);

		return {
			'key': key,
			'duration': duration,
			'chromagram': chromagram,
		};
	}
}
