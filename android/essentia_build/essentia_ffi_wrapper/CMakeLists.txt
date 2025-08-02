cmake_minimum_required(VERSION 3.10)

project(essentia_ffi LANGUAGES C CXX)

add_library(essentia_fii SHARED essentia_ffi_wrapper.cpp)

target_include_directories(essentia_fii PRIVATE include /build/essentia-install/static/arm64-v8a/include)

set(ESSENTIA_LIB_PATH "../output/static/arm64-v8a/lib/libessentia.a")

target_link_libraries(essentia_fii /build/essentia-install/static/arm64-v8a/lib/libessentia.a log)
