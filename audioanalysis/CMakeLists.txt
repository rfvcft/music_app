cmake_minimum_required(VERSION 3.10)
project(audioanalysis)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Allow user to specify platform: macos (default), ios, android
if(NOT DEFINED PLATFORM)
    set(PLATFORM "macos")
endif()

include_directories(
    include
)

set(AUDIOANALYSIS_SOURCES
    src/audioanalyzer.cpp
    src/capi.cpp
    src/chromaconverter.cpp
    src/chromaenhancer.cpp
    src/fouriertransformer.cpp
    src/framecutter.cpp
    src/keyfinder.cpp
    src/peakfinder.cpp
)


if (PLATFORM STREQUAL "macos")
    # Compile an executable for macOS
    add_executable(analyze ${AUDIOANALYSIS_SOURCES} src/main.cpp)

    # Link with Accelerate framework for fast FFT implementation
    target_link_libraries(analyze "-framework Accelerate")

elseif (PLATFORM STREQUAL "linux")
    # Compile main.cpp as executable for Linux by
    #   1. creating a build directory and navigating into it
    #   2. running cmake -DPLATFORM=linux /path/to/audioanalysis
    #   3. running cmake --build .
    #   4. running cmake --install .
    add_executable(analyze ${AUDIOANALYSIS_SOURCES} src/audioloader.cpp src/main.cpp)
    target_include_directories(analyze PRIVATE ../third_party/pocketfft ../third_party/dr_libs)

elseif(PLATFORM STREQUAL "ios")
    # Get the path to the iOS SDK
    execute_process(
        COMMAND xcrun --sdk iphoneos --show-sdk-path
        OUTPUT_VARIABLE IOS_SDK_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(CMAKE_OSX_SYSROOT ${IOS_SDK_PATH})

    # Architecture arm64 for modern iOS devices
    set(CMAKE_OSX_ARCHITECTURES arm64)
    add_library(audioanalysis STATIC ${AUDIOANALYSIS_SOURCES})

    # Link with Accelerate framework for fast FFT implementation
    target_link_libraries(audioanalysis "-framework Accelerate")

    # Set the output directory for the iOS static library
    set_target_properties(audioanalysis PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/ios"
    )

elseif(PLATFORM STREQUAL "android")
    set(BUILD_SHARED_LIBS ON)
    if (NOT DEFINED ANDROID_PLATFORM)
        set(ANDROID_PLATFORM "android-21")
    endif()
    if (NOT DEFINED ANDROID_NATIVE_API_LEVEL)
        set(ANDROID_NATIVE_API_LEVEL 21)
    endif()

    add_library(audioanalysis SHARED ${AUDIOANALYSIS_SOURCES} src/audioloader.cpp)
    target_include_directories(
            audioanalysis PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/pocketfft
            ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/dr_libs
    )
else() 
    message(FATAL_ERROR "Unknown platform: ${PLATFORM}. Supported platforms are: macos, ios, linux, android.")
    
endif()





