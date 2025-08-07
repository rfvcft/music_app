cmake_minimum_required(VERSION 3.10)

project(essentia_ffi LANGUAGES C CXX)

add_library(essentia_ffi SHARED essentia_ffi_wrapper.cpp)

target_include_directories(essentia_ffi PRIVATE
        include
        /build/static/include
        /build/dependencies/fftw/include
)

target_link_libraries(essentia_ffi
        /build/static/lib/libessentia.a
        /build/dependencies/fftw/lib/libfftw3f.a
        m
        log
)
