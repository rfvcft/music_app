# Dockerfile for building Android native libraries using Android NDK
#
# Usage:
# Install Docker
#
# Build the image once by running:
#   docker build -t "audioanalysis_builder" /path/to/directory/containing/this/Dockerfile
# Repeat this step only when this file has been modified. This can take a few minutes requires
# approximately 2.5GB of disk space.
#
# Cross-compile audioanalysis for android by running:
#   docker run --rm -it -v /path/to/music_app:/app -v /build_audioanalysis audioanalysis_builder:latest
# Specify a build type (Debug or Release, default: Debug) and whether to clean old make files before
# building (default: false) by adding the following flags to the above command:
#   -e BUILD_TYPE=Release
#   -e CLEAN_BUILD=true

FROM debian:bookworm-slim

# install basic tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    ca-certificates \
    cmake \
    make \
    && rm -rf /var/lib/apt/lists/*

# LTS Android NDK version
ENV ANDROID_NDK_VERSION=r27d
ENV ANDROID_NDK_DOWNLOAD_URL=https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip

# download and install Android NDK
WORKDIR /opt
RUN wget ${ANDROID_NDK_DOWNLOAD_URL} && \
    unzip android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    rm android-ndk-${ANDROID_NDK_VERSION}-linux.zip
ENV ANDROID_NDK_HOME=/opt/android-ndk-${ANDROID_NDK_VERSION}


# this is where the project files will be mounted
WORKDIR /app

# Build native code for different Android ABIs

# Android ABI targets
ENV ANDROID_ABIS="arm64-v8a armeabi-v7a x86_64"
ENV ANDROID_API_LEVEL=21
# Build type: Debug or Release
ENV BUILD_TYPE=Debug
# Don't delete make files to allow incremental builds
ENV CLEAN_BUILD=false

# directory containing native source code
ENV SOURCE_DIR=/app/audioanalysis
# directory of third party source code
ENV THIRD_PARTY_DIR=/app/third_party
# directory to be used by cmake and make for build files
ENV BUILD_DIR=/build_audioanalysis
# output directory for built libraries
ENV OUTPUT_DIR=/app/android/app/src/main/jniLibs

# copy the build script into the image
COPY build_audioanalysis.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/build_audioanalysis.sh

# run build script on container start
CMD ["build_audioanalysis.sh"]
