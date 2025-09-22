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
add_library(stub-annotations INTERFACE)
add_library(current_android_jar INTERFACE)
add_library(private-stub-annotations-jar INTERFACE)

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
baker(build/soong/java/core-libraries/ EXCLUDE_FROM_ALL)
baker(libcore/ EXCLUDE_FROM_ALL)
baker(libnativehelper/ EXCLUDE_FROM_ALL)
baker(prebuilts/r8/ EXCLUDE_FROM_ALL OUTPUT "prebuilts/r8/CMakeLists.txt") # no recursive
baker(external/conscrypt/ EXCLUDE_FROM_ALL)
baker(external/cpu_features/ EXCLUDE_FROM_ALL)
baker(external/dlmalloc/ EXCLUDE_FROM_ALL)
baker(external/fdlibm/ EXCLUDE_FROM_ALL)
baker(external/googletest/ EXCLUDE_FROM_ALL)
baker(external/icu EXCLUDE_FROM_ALL)
baker(external/lz4/lib/ EXCLUDE_FROM_ALL)
baker(external/lzma/ EXCLUDE_FROM_ALL)
baker(external/okhttp/ EXCLUDE_FROM_ALL)
baker(external/protobuf/ EXCLUDE_FROM_ALL)
baker(external/tinyxml2/ EXCLUDE_FROM_ALL)
baker(external/zstd/ EXCLUDE_FROM_ALL)
baker(system/libbase/ EXCLUDE_FROM_ALL)
baker(system/libprocinfo/ EXCLUDE_FROM_ALL)
baker(system/logging/liblog/ EXCLUDE_FROM_ALL)
baker(system/core/libsystem/ EXCLUDE_FROM_ALL)
baker(system/core/libutils/ EXCLUDE_FROM_ALL)
baker(system/hardware/interfaces/ EXCLUDE_FROM_ALL)
baker(system/tools/aidl/ EXCLUDE_FROM_ALL)
baker(system/libziparchive/ EXCLUDE_FROM_ALL)
baker(system/unwinding/libunwindstack/ EXCLUDE_FROM_ALL)
baker(tools/platform-compat/java/android/compat/annotation/ EXCLUDE_FROM_ALL)
baker(frameworks/base/ EXCLUDE_FROM_ALL)
baker(frameworks/libs/modules-utils/java/ EXCLUDE_FROM_ALL)
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
add_library(libz-static STATIC IMPORTED GLOBAL)
set_target_properties(libz-static PROPERTIES
    IMPORTED_LOCATION "${ZLIB_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIRS}"
)

# Fix for missing linkage
set_property(TARGET liblog.defaults APPEND PROPERTY _export_header_lib_headers libutils_headers)
target_link_libraries(libmath-static PUBLIC libutils_headers)
target_link_libraries(dalvikvm PRIVATE libart-shared)
# Fix for these defaults which use directories with relative paths from the root
target_include_directories(gtest_test_defaults INTERFACE external/googletest/googletest/)
target_include_directories(gtest_ndk_test_defaults INTERFACE external/googletest/googletest/)

# fmtlib_test_2 will fail because the locale problem
set_tests_properties(fmtlib_test_2 DIRECTORY external/fmtlib/ PROPERTIES WILL_FAIL TRUE)

# Only build part of tests by default to speed up
set_property(TARGET aidl_unittests PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET boringssl_crypto_test PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET libcrypto-shared PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET art-aconfig-flags-lib-static PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET art_libartbase_operator_srcs PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET asm_defines.s PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET libart-shared PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET libjavacore-unit-tests PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET core.current.stubs.from-text PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET libcore-bootstrap-core-current-from-text-system-modules PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET libcore-bootstrap-lib-for-flags-lib PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET libcore-aconfig-flags-lib-for-core-all-only PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET core_oj_api_files PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET art.module.intra.core.api_.public.stubs.source_ PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET core-all PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET core-oj PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET core-icu4j PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET android-non-updatable-doc-stubs PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET framework-protos PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET android-non-updatable.stubs.module_lib PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET android_module_lib_stubs_current PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET modules-utils-fastxmlserializer PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET all-modules-system-stubs PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET android_system_stubs_current PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET soundtrigger_middleware-aidl-java PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET mime.types.minimized PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET mimemap-res.jar PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET modules-utils-list-slice PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET android.system.suspend.control.internal-java PROPERTY EXCLUDE_FROM_ALL FALSE)
set_property(TARGET mimemap PROPERTY EXCLUDE_FROM_ALL FALSE)
# Currently cmake does not support EXCLUDE_FROM_ALL for sub-subdirectory, so workaround
get_property(aidl_targets DIRECTORY system/tools/aidl/build PROPERTY BUILDSYSTEM_TARGETS)
foreach(target IN LISTS aidl_targets)
    get_target_property(type ${target} TYPE)
    if(NOT "${type}" STREQUAL "INTERFACE_LIBRARY" AND NOT "${type}" STREQUAL "UTILITY")
        set_property(TARGET ${target} PROPERTY EXCLUDE_FROM_ALL FALSE)
    endif()
endforeach()

set_tests_properties(boringssl_crypto_test DIRECTORY external/boringssl/ PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/external/boringssl/src/)
# FIXME: boringssl_crypto_test fails with libcrypto-shared
get_property(boringssl_test_support_libs TARGET .boringssl_test_support.OBJ PROPERTY LINK_LIBRARIES)
set_property(TARGET .boringssl_test_support.OBJ PROPERTY LINK_LIBRARIES "$<LIST:FILTER,${boringssl_test_support_libs},EXCLUDE,libcrypto-shared>")
get_property(boringssl_test_support_libs TARGET .boringssl_test_support.OBJ PROPERTY INTERFACE_LINK_LIBRARIES)
set_property(TARGET .boringssl_test_support.OBJ PROPERTY INTERFACE_LINK_LIBRARIES "$<LIST:FILTER,${boringssl_test_support_libs},EXCLUDE,libcrypto-shared>")
get_property(boringssl_test_support_libs TARGET boringssl_test_support-static PROPERTY LINK_LIBRARIES)
set_property(TARGET boringssl_test_support-static PROPERTY LINK_LIBRARIES "$<LIST:FILTER,${boringssl_test_support_libs},EXCLUDE,libcrypto-shared>")
get_property(boringssl_test_support_libs TARGET boringssl_test_support-static PROPERTY INTERFACE_LINK_LIBRARIES)
set_property(TARGET boringssl_test_support-static PROPERTY INTERFACE_LINK_LIBRARIES "$<LIST:FILTER,${boringssl_test_support_libs},EXCLUDE,libcrypto-shared>")
target_link_libraries(.boringssl_test_support.OBJ PRIVATE libcrypto_static-static)
set_property(TARGET conscrypt_generate_constants PROPERTY LINK_LIBRARIES "")
target_link_libraries(conscrypt_generate_constants PRIVATE libcrypto_static-static)

# libbinder includes stdatomic.h, which may not work until C++23
set_target_properties(.libbinder.OBJ PROPERTIES CXX_STANDARD 23)

# Default bfd linker may fail to link with protected symbols
target_link_options(art_defaults INTERFACE "-fuse-ld=lld")
# Add some extra definitions for ART, from art/build/art.go
target_compile_definitions(art_defaults INTERFACE
    "-DUSE_D8_DESUGAR=1"
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
set_property(TARGET protobuf-cflags-defaults PROPERTY _cflags "")
# mime.types.minimized references android.mime.types.minimized in device_common_srcs
target_link_libraries(mime.types.minimized INTERFACE android.mime.types.minimized)
add_dependencies(mime.types.minimized android.mime.types.minimized)
# Force android.system.suspend.control.internal-java to use current sdk instead of 28
set_target_properties(.android.system.suspend.control.internal-java.SRC PROPERTIES _sdk_version "system_current")

# Some stubs library for android_system_stubs_current
add_library(framework-media.stubs.system INTERFACE)
set_target_properties(framework-media.stubs.system PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/system/framework-media.jar")
set_target_properties(framework-media.stubs.system PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
add_library(framework-connectivity.stubs.system INTERFACE)
set_target_properties(framework-connectivity.stubs.system PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/system/framework-connectivity.jar")
set_target_properties(framework-connectivity.stubs.system PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
add_library(framework-appsearch.stubs.system INTERFACE)
set_target_properties(framework-appsearch.stubs.system PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/system/framework-appsearch.jar")
set_target_properties(framework-appsearch.stubs.system PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
add_library(framework-bluetooth.stubs.system INTERFACE)
set_target_properties(framework-bluetooth.stubs.system PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/system/framework-bluetooth.jar")
set_target_properties(framework-bluetooth.stubs.system PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
add_library(framework-graphics.stubs.system INTERFACE)
set_target_properties(framework-graphics.stubs.system PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/system/framework-graphics.jar")
set_target_properties(framework-graphics.stubs.system PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
add_library(android.net.ipsec.ike.stubs.system INTERFACE)
set_target_properties(android.net.ipsec.ike.stubs.system PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/system/android.net.ipsec.ike.jar")
set_target_properties(android.net.ipsec.ike.stubs.system PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
add_library(framework-wifi.stubs.system INTERFACE)
set_target_properties(framework-wifi.stubs.system PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/system/framework-wifi.jar")
set_target_properties(framework-wifi.stubs.system PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")

# Patch baker at the end
baker_patch()

# r8 depends on r8lib built from prebuilts/r8, so we can not leave it in java.cmake
if(EXISTS "${CMAKE_SOURCE_DIR}/prebuilts/r8")
    # Copy prebuilt r8
    include(ExternalProject)
    ExternalProject_Add(r8_build
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/prebuilts/r8
        BUILD_IN_SOURCE TRUE
        CONFIGURE_COMMAND
            "${CMAKE_COMMAND}" -E make_directory ${CMAKE_BINARY_DIR}/r8/framework/ &&
            "${CMAKE_COMMAND}" -E make_directory ${CMAKE_BINARY_DIR}/r8/bin/
        BUILD_COMMAND ""
        INSTALL_COMMAND
            "${CMAKE_COMMAND}" -E copy ${CMAKE_SOURCE_DIR}/prebuilts/r8/d8 ${CMAKE_BINARY_DIR}/r8/bin/d8 &&
            "${CMAKE_COMMAND}" -E copy $<TARGET_PROPERTY:r8lib,INTERFACE__CLASSPATH_> ${CMAKE_BINARY_DIR}/r8/framework/d8.jar
        BUILD_BYPRODUCTS "${CMAKE_BINARY_DIR}/r8/bin/d8" "${CMAKE_BINARY_DIR}/r8/framework/d8.jar"
        DEPENDS r8lib
    )
    # Import the built binary
    add_executable(d8 IMPORTED GLOBAL)
    add_dependencies(d8 r8_build)
    set_target_properties(d8 PROPERTIES IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/r8/bin/d8)
endif()

if(EXISTS "${CMAKE_SOURCE_DIR}/prebuilts/build-tools/linux-x86/bin/soong_zip")
    # Import the built binary
    add_executable(soong_zip IMPORTED GLOBAL)
    set_target_properties(soong_zip PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/prebuilts/build-tools/linux-x86/bin/soong_zip)
endif()

# Add prebuilts sdk, see build/soong/java/prebuilt_apis.go
add_library(sdk_system_current_android INTERFACE)
set_target_properties(sdk_system_current_android PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/system/android.jar")
set_target_properties(sdk_system_current_android PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
add_library(sdk_module-lib_current_framework-connectivity-t INTERFACE)
set_target_properties(sdk_module-lib_current_framework-connectivity-t PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_SOURCE_DIR}/prebuilts/sdk/current/module-lib/framework-connectivity-t.jar")
set_target_properties(sdk_module-lib_current_framework-connectivity-t PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")