cmake_minimum_required(VERSION 3.14)
project(essentia_c_api LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


# Set iOS toolchain and architectures
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
execute_process(
	COMMAND xcrun --sdk iphoneos --show-sdk-path
	OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
	OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(CMAKE_OSX_SYSROOT ${CMAKE_OSX_SYSROOT})

include_directories(
	${CMAKE_CURRENT_SOURCE_DIR}/essentia_installation/include
	${CMAKE_CURRENT_SOURCE_DIR}/../essentia_c_api/include
)

add_library(essentia_c_api STATIC
	${CMAKE_CURRENT_SOURCE_DIR}/../essentia_c_api/src/c_api.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../essentia_c_api/src/algorithms.cpp
)

target_link_libraries(essentia_c_api
	PUBLIC
	${CMAKE_CURRENT_SOURCE_DIR}/essentia_installation/lib/libessentia.a
	# Add system frameworks if needed, e.g. Accelerate
	"-framework Accelerate"
)

target_include_directories(essentia_c_api PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../essentia_c_api/include>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/essentia_installation/include>
)

