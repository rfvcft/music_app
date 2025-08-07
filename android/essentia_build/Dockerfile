####################################################################################################
# Build Android .so binaries for Essentia with FFTW + dependencies + C-FFI-wrapper
#
# Use this Dockerfile for cross-compiling essentia for android by running the following command from
# this directory. The complete build process may take up to 10 minutes and requires a stable
# internet connection for downloading the necessary compilers.
#   $   docker buildx build --platform=linux/amd64 --target final --output /path/to/output .
# The compiled shared libraries (.so files) will be written to the /path/to/output directory.
# Intermediate build steps are cached and running the command again will rebuild only from the first
# change onwards. The cache takes approximately 2.5GB of disk space. To delete the cache, free up
# the disk space and rebuild everything from scratch run:
#   $   docker buildx prune
#
# Supported architectures:
#  - arm64-v8a
#
# Folder structure:
# /build/
# ├── android-ndk/                          # Android NDK: C/C++ compilers for android architectures
# ├── fftw/                                 # unzipped FFTW download
# ├── essentia/                             # essentia source code cloned from GitHub repository
# ├── dependencies/                         # pre-compiled third-party dependencies for essentia
# │   └── fftw/                             # FFTW (Fourier transform) static binaries built by make
# │       ├── include/                      # FFTW header files
# │       ├── lib/libfftw3f.a               # statically pre-compiled FFTW binary
# │       └── lib/pkgconfig/fftw3f.pc       # contains package metadata for waf build
# │
# ├── essentia_ffi_wrapper/                 # exact copy of
# │                                           music_app/android/essentia_build/essentia_ffi_wrapper
# ├── static/                               # essentia static binaries built by python waf
# │   ├── include/                          # essentia header files
# │   └── lib/libessentia.a                 # statically compiled essentia binary
# │
# ├── dynamic/libessentia_ffi.so            # final dynamic FFI-compatible binary built by cmake
# │                                           from
# │                                            - libessentia.a from /build/static/
# │                                            - pre-compiled binaries from /build/dependencies/
# │                                            - essentia_ffi_wrapper/
# └── logs/                          # log files with output of selected build commands
#     ├── waf-essentia/                     # output of waf during essentia compiling
#     │   ├── configure.log
#     │   ├── build.log
#     │   └── install.log
#     ├── make-fftw/                        # output of make during FFTW compiling
#     │   ├── configure.log
#     │   └── install.log
#     └── cmake-essentia_ffi_wrapper/       # output of cmake during final FFI-compatible compiling
#         ├── configure.log
#         └── build.log
#
####################################################################################################



# --------------------------------------------------------------------------------------------------
# Stage 1: Setup base system
# Install basic tools, download Android NDK, download all required source code.
# --------------------------------------------------------------------------------------------------
FROM ubuntu:22.04 AS base

WORKDIR /build


# --- Basic setup ----------------------------------------------------------------------------------

# Execute terminal commands in non-interactive mode if possible (e.g. not asking for confirmation).
ENV DEBIAN_FRONTEND=noninteractive

# Install various tools needed for the build process:
#  - build-essential contains make
#  - python-is-python3 allows waf to call python3 as python
#  - python3-setuptools is sometimes internally used by waf
#  - pkg-config allows use of .pc files
#  - ca-certificates for HTTPS connections
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip build-essential python3 python-is-python3 python3-setuptools git pkg-config cmake ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# create directories for logs
RUN mkdir -p /build/logs/make-fftw /build/logs/waf-essentia /build/logs/cmake-essentia_ffi_wrapper


# --- Download essentia source code ----------------------------------------------------------------

# essentia version and clone code from GitHub
ENV ESSENTIA_VERSION=v2.1_beta5
RUN git clone --branch ${ESSENTIA_VERSION} --depth 1 https://github.com/MTG/essentia.git


# --- Android NDK setup ----------------------------------------------------------------------------

# Android NDK version and download URL
# TODO: change NDK version?
ENV ANDROID_NDK_VERSION=r25b
ENV ANDROID_NDK_URL=https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip

# download and unzip Android NDK, rename to android-ndk and delete zip archive
RUN curl -LO ${ANDROID_NDK_URL} && \
    unzip android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    mv android-ndk-${ANDROID_NDK_VERSION} android-ndk && \
    rm android-ndk-${ANDROID_NDK_VERSION}-linux.zip

# set Android NDK root variable and add NDK toolchains to path
ENV ANDROID_NDK_ROOT=/build/android-ndk
ENV PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}


# --- Download source code of dependencies ---------------------------------------------------------

# FFTW version and download URL
ENV FFTW_VERSION=3.3.10
ENV FFTW_URL=https://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz

# download and unzip FFTW, rename to fftw and delete tar.gz package
RUN curl -LO ${FFTW_URL} && \
    tar xzf fftw-${FFTW_VERSION}.tar.gz && \
    mv fftw-${FFTW_VERSION} fftw && \
    rm fftw-${FFTW_VERSION}.tar.gz



# --------------------------------------------------------------------------------------------------
# Stage 2.1: Cross-compile essentia for android arm64-v8a
# --------------------------------------------------------------------------------------------------
FROM base AS build-arm64


# configure compiler toolchain for cross-compiling to Android arm64-v8a
ENV HOST=aarch64-linux-android
ENV CC=aarch64-linux-android21-clang
ENV CXX=aarch64-linux-android21-clang++
ENV AR=llvm-ar
ENV AS=llvm-as
ENV LD=ld
ENV RANLIB=llvm-ranlib
ENV STRIP=llvm-strip


# --- Essentia dependency: pre-compile static FFTW build using make --------------------------------

WORKDIR /build/fftw

# static make build of fftw
RUN ./configure \
      --host=$HOST \
      --enable-static \
      --disable-shared \
      --with-pic \
      --enable-single \
      --prefix=/build/dependencies/fftw \
      CC=$CC AR=$AR RANLIB=$RANLIB \
      2>&1 | tee /build/logs/make-fftw/configure.log && \
    make install \
      2>&1 | tee /build/logs/make-fftw/install.log


# --- Static build of essentia using python waf ----------------------------------------------------

WORKDIR /build/essentia

# provide dependencies via pkg-config
ENV PKG_CONFIG_PATH=/build/dependencies/fftw/lib/pkgconfig

# static waf build of essentia and write output stdout and to log files
RUN ./waf configure \
      --cross-compile-android \
      --build-static \
      --fft=FFTW \
      --prefix=/build/static \
      2>&1 | tee /build/logs/waf-essentia/configure.log && \
    ./waf build \
      2>&1 | tee /build/logs/waf-essentia/build.log && \
    ./waf install \
      2>&1 | tee /build/logs/waf-essentia/install.log


# --- Compile with FFI-compatible wrapper to final shared library libessentia_ffi.so ---------------

# copy the essentia FFI wrapper into the image
COPY essentia_ffi_wrapper /build/essentia_ffi_wrapper

WORKDIR /build/dynamic

# dynamic cmake build of essentia FFI wrapper and the precompiled static essentia build
RUN cmake /build/essentia_ffi_wrapper \
      -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT"/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-21 \
      -DCMAKE_BUILD_TYPE=Release \
      2>&1 | tee /build/logs/cmake-essentia_ffi_wrapper/configure.log && \
    cmake --build . \
      2>&1 | tee /build/logs/cmake-essentia_ffi_wrapper/build.log



# TODO: Add stage 2.2 for android x86_64


# --------------------------------------------------------------------------------------------------
# Stage 3: Output cross-compiled shared libraries for android
# --------------------------------------------------------------------------------------------------
FROM scratch AS final

# copy only the final .so files into this stage
COPY --from=build-arm64 /build/dynamic/libessentia_ffi.so /libs/arm64-v8a/libessentia_ffi.so

# copy log files from the previous stage
COPY --from=build-arm64 /build/logs /logs/arm64-v8a
