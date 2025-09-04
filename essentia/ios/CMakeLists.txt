
# Minimum required CMake version
cmake_minimum_required(VERSION 3.14)

# Project name and language
project(essentia_c_api LANGUAGES CXX)


# Use C++14 standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)



# Set iOS toolchain and architectures
# Only build for arm64 (Apple Silicon)
set(CMAKE_OSX_ARCHITECTURES arm64)
# Enable position independent code (required for shared/static libs on iOS)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
# Get the iOS SDK path using xcrun
execute_process(
	COMMAND xcrun --sdk iphoneos --show-sdk-path
	OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
	OUTPUT_STRIP_TRAILING_WHITESPACE
)
# Set the sysroot to the iOS SDK path
set(CMAKE_OSX_SYSROOT ${CMAKE_OSX_SYSROOT})


# Add include directories for Essentia and C-API headers
include_directories(
	${CMAKE_CURRENT_SOURCE_DIR}/essentia_installation/include
	${CMAKE_CURRENT_SOURCE_DIR}/../essentia_c_api/include
)


# Create static library from C-API source files
add_library(essentia_c_api STATIC
	${CMAKE_CURRENT_SOURCE_DIR}/../essentia_c_api/src/c_api.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../essentia_c_api/src/algorithms.cpp
)


# Link Essentia static library and Accelerate framework 
target_link_libraries(essentia_c_api
	PUBLIC
	${CMAKE_CURRENT_SOURCE_DIR}/essentia_installation/lib/libessentia.a
	"-framework Accelerate" # For FFT 
)


# Specify include directories for consumers of the library
target_include_directories(essentia_c_api PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../essentia_c_api/include>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/essentia_installation/include>
)

