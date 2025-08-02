#!/bin/bash

./waf configure --cross-compile-android --build-static --static-dependencies --fft=KISS --prefix=/build/essentia-install/static/arm64-v8a
./waf build
./waf install

mkdir /build/essentia-install/dynamic && cd /build/essentia-install/dynamic

cmake /build/essentia_ffi_wrapper \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT"/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  -DCMAKE_BUILD_TYPE=Release

cmake --build .


exec "$@"
