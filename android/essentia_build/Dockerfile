FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# tools and dependencies
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

ENV ANDROID_NDK_HOME=/build/android-ndk-${ANDROID_NDK_VERSION}
ENV PATH=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH

# essentia version
ENV ESSENTIA_VERSION=v2.1_beta5

# clone essentia code from GitHub
RUN git clone --branch ${ESSENTIA_VERSION} --depth 1 https://github.com/MTG/essentia.git

WORKDIR /build/essentia

# Set environment for cross-compiling to Android arm64-v8a
ENV ANDROID_NDK_ROOT=/build/android-ndk-${ANDROID_NDK_VERSION}
ENV PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH

ENV CC=aarch64-linux-android21-clang
ENV CXX=aarch64-linux-android21-clang++

COPY _entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY essentia_ffi_wrapper /build/essentia_ffi_wrapper

ENTRYPOINT ["/entrypoint.sh"]

# output directory
VOLUME ["/build/essentia-install"]

