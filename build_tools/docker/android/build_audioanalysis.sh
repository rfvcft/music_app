#!/bin/bash
# Don't run this script directly. This intended to be run in a Docker container.
# Build native C/C++ code for different Android ABIs using cmake.

# Delete old make files and caches to guarantee a clean build if CLEAN_BUILD is set to true.
if $CLEAN_BUILD; then
  echo "> Clean build directory..."
  if [ -d "$BUILD_DIR" ]; then
    rm -rf "${BUILD_DIR:?}"/*
  else
    echo "    No build directory found, skipping."
  fi
  echo "  Done"
fi

for ABI in $ANDROID_ABIS; do
  echo "> Building for Android ABI $ABI..."

  echo "  > Configure cmake..."
    cmake -S "$SOURCE_DIR" \
          -B "$BUILD_DIR/$ABI" \
          -DPLATFORM=android \
          -DANDROID_ABI="$ABI" \
          -DANDROID_STL=c++_static \
          -DANDROID_PLATFORM="$ANDROID_API_LEVEL" \
          -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
          -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
          2>&1 | sed 's/^/      /'
  echo "    Done."

  echo "  > Build shared libraries..."
    cmake --build "$BUILD_DIR/$ABI" 2>&1 | sed 's/^/      /'
  echo "    Done."

  echo "  > Copy built libraries to jniLibs..."
    mkdir -p "$OUTPUT_DIR/$ABI"
    cp "$BUILD_DIR/$ABI/libaudioanalysis.so" "$OUTPUT_DIR/$ABI/"
  echo "    Done."

  echo "  Build for ABI $ABI successful."
  echo ""
done
