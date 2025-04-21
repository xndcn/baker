cmake_minimum_required(VERSION 3.28)
# set_tests_properties with DIRECTORY requires CMake 3.28
project(BakerTest CXX ASM)

# Set C++20 as the standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add linker flag to fail if symbols are missing in shared libraries
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")

# Add option to skip baker execution
option(SKIP_BAKER "Skip execution of baker command" OFF)

include(CTest)
include(cmake/baker.cmake)

# Currently not used library
add_library(libprocessgroup_headers INTERFACE)
add_library(libprocessgroup-static INTERFACE)
add_library(libprocessgroup-shared INTERFACE)
add_library(libjsoncpp-static INTERFACE)

# Most Android.bp add -Werror flags, but create a lot of errors
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -w")

set(TARGET "linux" ; "glibc" ; "host")
baker(external/fmtlib/)
baker(external/libcap/)
baker(system/core/libcutils/)
baker(frameworks/native/libs/math/)


# Currently not built by default
baker(art/ EXCLUDE_FROM_ALL)
baker(external/googletest/ EXCLUDE_FROM_ALL)
baker(system/libbase/ EXCLUDE_FROM_ALL)
baker(system/logging/liblog/ EXCLUDE_FROM_ALL)
baker(system/core/libsystem/ EXCLUDE_FROM_ALL)
baker(system/core/libutils/ EXCLUDE_FROM_ALL)
baker(system/tools/aidl/ EXCLUDE_FROM_ALL)
baker(frameworks/native/libs/binder/ EXCLUDE_FROM_ALL)
# boringssl requires some Android specific flags
set(TARGET "android" ; "linux" ; "glibc" ; "host")
baker(external/boringssl/ EXCLUDE_FROM_ALL)

# Add alias for gtest and gmock
add_library(gmock ALIAS libgmock-static)
add_library(gtest ALIAS libgtest-static)
add_library(gtest_main ALIAS libgtest_main-static)

# Fix for missing linkage
set_property(TARGET liblog.defaults APPEND PROPERTY _export_header_libs libutils_headers)
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

set_tests_properties(boringssl_crypto_test DIRECTORY external/boringssl/ PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/external/boringssl/src/)
# FIXME: boringssl_crypto_test fails with libcrypto-shared
get_property(boringssl_test_support_libs TARGET boringssl_test_support-static PROPERTY LINK_LIBRARIES)
set_property(TARGET boringssl_test_support-static PROPERTY LINK_LIBRARIES "$<LIST:FILTER,${boringssl_test_support_libs},EXCLUDE,libcrypto-shared>")
get_property(boringssl_test_support_libs TARGET boringssl_test_support-static PROPERTY INTERFACE_LINK_LIBRARIES)
set_property(TARGET boringssl_test_support-static PROPERTY INTERFACE_LINK_LIBRARIES "$<LIST:FILTER,${boringssl_test_support_libs},EXCLUDE,libcrypto-shared>")
target_link_libraries(boringssl_test_support-static PRIVATE libcrypto_static)

# Patch defaults at the end
baker_patch_defaults()