#!/bin/bash
docker build -t essentia-android .
docker run --rm \
  -v "$(pwd)/output:/build/essentia-install" \
  essentia-android

echo "Docker essentia build for Android arm64-v8a successful."

cp output/dynamic/libessentia_fii.so ../app/src/main/jniLibs/arm64-v8a/
