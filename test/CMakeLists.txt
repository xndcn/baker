cmake_minimum_required(VERSION 3.28)
# set_tests_properties with DIRECTORY requires CMake 3.28
project(BakerTest CXX ASM)

# Set C++20 as the standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add linker flag to fail if symbols are missing in shared libraries
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")
# Some hacks of include headers to avoid errors
include_directories(mock-include)

# Add option to skip baker execution
option(SKIP_BAKER "Skip execution of baker command" OFF)

include(CTest)
include(cmake/baker.cmake)

# Currently not used library
add_library(libprocessgroup_headers INTERFACE)
add_library(libprocessgroup-static INTERFACE)
add_library(libprocessgroup-shared INTERFACE)
add_library(libjsoncpp-static INTERFACE)
add_library(librustc_demangle_static-static STATIC ".")
set_target_properties(librustc_demangle_static-static PROPERTIES LINKER_LANGUAGE CXX)

# Most Android.bp add -Werror flags, but create a lot of errors
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -w")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -w")

set(ARCH "x86_64")
set(CODEGEN "x86_64" ; "x86")
set(TARGET "linux" ; "glibc" ; "host")
baker(external/fmtlib/)
baker(external/libcap/)
baker(system/core/libcutils/)
baker(frameworks/native/libs/math/)


# Currently not built by default
baker(art/ EXCLUDE_FROM_ALL)
baker(libcore/ EXCLUDE_FROM_ALL)
baker(libnativehelper/ EXCLUDE_FROM_ALL)
baker(external/cpu_features/ EXCLUDE_FROM_ALL)
baker(external/dlmalloc/ EXCLUDE_FROM_ALL)
baker(external/fdlibm/ EXCLUDE_FROM_ALL)
baker(external/googletest/ EXCLUDE_FROM_ALL)
baker(external/icu EXCLUDE_FROM_ALL)
baker(external/lz4/lib/ EXCLUDE_FROM_ALL)
baker(external/lzma/ EXCLUDE_FROM_ALL)
baker(external/tinyxml2/ EXCLUDE_FROM_ALL)
baker(external/zstd/ EXCLUDE_FROM_ALL)
baker(system/libbase/ EXCLUDE_FROM_ALL)
baker(system/libprocinfo/ EXCLUDE_FROM_ALL)
baker(system/logging/liblog/ EXCLUDE_FROM_ALL)
baker(system/core/libsystem/ EXCLUDE_FROM_ALL)
baker(system/core/libutils/ EXCLUDE_FROM_ALL)
baker(system/tools/aidl/ EXCLUDE_FROM_ALL)
baker(system/libziparchive/ EXCLUDE_FROM_ALL)
baker(system/unwinding/libunwindstack/ EXCLUDE_FROM_ALL)
baker(frameworks/native/libs/binder/ EXCLUDE_FROM_ALL)
# boringssl requires some Android specific flags
set(TARGET "android" ; "linux" ; "glibc" ; "host")
baker(external/boringssl/ EXCLUDE_FROM_ALL)

# Add alias for gtest and gmock
add_library(gmock ALIAS libgmock-static)
add_library(gtest ALIAS libgtest-static)
add_library(gtest_main ALIAS libgtest_main-static)

# Add alias for libz-shared
find_package(ZLIB REQUIRED)
add_library(libz-shared INTERFACE)
target_link_libraries(libz-shared INTERFACE ZLIB::ZLIB)

# Fix for missing linkage
set_property(TARGET liblog.defaults APPEND PROPERTY _export_header_lib_headers libutils_headers)
target_link_libraries(libmath-static PUBLIC libutils_headers)
# Fix for these defaults which use directories with relative paths from the root
target_include_directories(gtest_test_defaults INTERFACE external/googletest/googletest/)
target_include_directories(gtest_ndk_test_defaults INTERFACE external/googletest/googletest/)

# fmtlib_test_2 will fail because the locale problem
set_tests_properties(fmtlib_test_2 DIRECTORY external/fmtlib/ PROPERTIES WILL_FAIL TRUE)

# Only build part of tests by default to speed up
set_property(TARGET aidl_unittests PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET boringssl_crypto_test PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET art-aconfig-flags-lib-static PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET art_libartbase_operator_srcs-gen PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET asm_defines.s PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET libart-shared PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET libjavacore-unit-tests PROPERTY EXCLUDE_FROM_ALL FALSE)

set_tests_properties(boringssl_crypto_test DIRECTORY external/boringssl/ PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/external/boringssl/src/)
# FIXME: boringssl_crypto_test fails with libcrypto-shared
get_property(boringssl_test_support_libs TARGET boringssl_test_support-static PROPERTY LINK_LIBRARIES)
set_property(TARGET boringssl_test_support-static PROPERTY LINK_LIBRARIES "$<LIST:FILTER,${boringssl_test_support_libs},EXCLUDE,libcrypto-shared>")
get_property(boringssl_test_support_libs TARGET boringssl_test_support-static PROPERTY INTERFACE_LINK_LIBRARIES)
set_property(TARGET boringssl_test_support-static PROPERTY INTERFACE_LINK_LIBRARIES "$<LIST:FILTER,${boringssl_test_support_libs},EXCLUDE,libcrypto-shared>")
target_link_libraries(boringssl_test_support-static PRIVATE libcrypto_static)

# Default bfd linker may fail to link with protected symbols
target_link_options(art_defaults INTERFACE "-fuse-ld=lld")
# Add some extra definitions for ART, from art/build/art.go
target_compile_definitions(art_defaults INTERFACE
    "-DART_TARGET"
    "-DART_TARGET_LINUX"
    "-DART_FRAME_SIZE_LIMIT=1744"
    "-DART_DEFAULT_GC_TYPE_IS_CMC"
    "-DART_BASE_ADDRESS=0x70000000"
    "-DART_BASE_ADDRESS_MIN_DELTA=(-0x1000000)"
    "-DART_BASE_ADDRESS_MAX_DELTA=0x1000000"
    "-DART_STACK_OVERFLOW_GAP_arm=8192"
    "-DART_STACK_OVERFLOW_GAP_arm64=8192"
    "-DART_STACK_OVERFLOW_GAP_riscv64=8192"
    "-DART_STACK_OVERFLOW_GAP_x86=8192"
    "-DART_STACK_OVERFLOW_GAP_x86_64=8192")
# Fix for using XSI-compliant strerror_r
set_property(TARGET libnativehelper_defaults PROPERTY _cflags "-U_GNU_SOURCE" ; "-D_POSIX_C_SOURCE=200112L")

# Patch defaults at the end
baker_patch_defaults()