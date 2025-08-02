import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

final DynamicLibrary essentiaLib = Platform.isAndroid
    ? DynamicLibrary.open("libessentia_ffi.so")
    : DynamicLibrary.process(); // for statically linked iOS-FFI

final _computeRms = essentiaLib
    .lookupFunction<Float Function(Pointer<Float>, Int32), double Function(Pointer<Float>, int)>('compute_rms');

double computeRms(List<double> samples) {
  final ptr = malloc<Float>(samples.length);
  for (int i = 0; i < samples.length; ++i) {
    ptr[i] = samples[i].toDouble();
  }
  final result = _computeRms(ptr, samples.length);
  malloc.free(ptr);
  return result;
}
