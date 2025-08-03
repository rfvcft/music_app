# Stage 1: Build binaries
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# install tools and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip build-essential python3 python3-pip python-is-python3 python3-setuptools git wget pkg-config cmake ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Android NDK version and download URL
ENV ANDROID_NDK_VERSION=r25b
ENV ANDROID_NDK_URL=https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip

WORKDIR /build

# download and unzip Android NDK
RUN curl -LO ${ANDROID_NDK_URL} && \
    unzip android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    rm android-ndk-${ANDROID_NDK_VERSION}-linux.zip

# essentia version
ENV ESSENTIA_VERSION=v2.1_beta5

# clone essentia code from GitHub
RUN git clone --branch ${ESSENTIA_VERSION} --depth 1 https://github.com/MTG/essentia.git

WORKDIR /build/essentia

# set Android NDK root variable and add to path
ENV ANDROID_NDK_ROOT=/build/android-ndk-${ANDROID_NDK_VERSION}
ENV PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}

# set environment for cross-compiling to Android arm64-v8a
ENV CC=aarch64-linux-android21-clang
ENV CXX=aarch64-linux-android21-clang++

# static waf build of essentia
RUN ./waf configure \
      --cross-compile-android \
      --build-static \
      --static-dependencies \
      --fft=KISS \
      --prefix=/build/static/arm64-v8a && \
    ./waf build && \
    ./waf install

# copy the essentia FFI wrapper into the image
COPY essentia_ffi_wrapper /build/essentia_ffi_wrapper

WORKDIR /build/dynamic/arm64-v8a

# dynamic cmake build of essentia FFI wrapper and the precompiled static essentia build
RUN cmake /build/essentia_ffi_wrapper \
      -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT"/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-21 \
      -DCMAKE_BUILD_TYPE=Release && \
    cmake --build .


# Stage 2: Output cross-compiled binary
FROM scratch AS output

COPY --from=builder /build/dynamic/arm64-v8a/libessentia_ffi.so /build/arm64-v8a/libessentia_ffi.so

