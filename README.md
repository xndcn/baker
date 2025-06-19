# baker
Android.bp to CMakeLists.txt Converter

## Overview
Baker is a tool that converts Android.bp build files to CMakeLists.txt, enabling Android native projects to be built with CMake.

## Module Types

| Android.bp Module | CMake Equivalent | Description |
|-------------------|------------------|-------------|
| `cc_library` | `add_library()` | Creates a native library (both static and shared) |
| `cc_binary` | `add_executable()` | Creates a native executable |
| `cc_test` | `add_executable()` + `add_test()` | Creates a test executable |
| `cc_defaults` | `set_property()` | Default properties set for other modules |
| `cc_object` | `add_executable()` | Creates an object file through partial linking |
| `cc_test_library` | `add_library()` | Creates a test library linked against gtest/gmock |

## Property Mapping

| Android.bp Property | CMake Equivalent | Description |
|---------------------|------------------|-------------|
| `srcs` | `target_sources()` | Source files for compilation |
| `include_dirs` | `target_include_directories()` | Include directories for headers |
| `cflags` | `target_compile_options()` | Compiler flags |
| `shared_libs` | `target_link_libraries()` | Shared libraries to link against |
| `defaults` | `apply_defaults()` | Default values inherited from cc_defaults |

## Usage
```bash
pip install -e .
baker /path/to/Android.bp
```

## Example

An example conversion from `art/runtime/Android.bp` to `art/runtime/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.30)
project(runtime)

set(JIT_DEBUG_REGISTER_CODE_LDFLAGS "-Wl,--keep-unique,__jit_debug_register_code" ; "-Wl,--keep-unique,__dex_debug_register_code")

baker_defaults(
  name "libart_nativeunwind_defaults"
  _target_ host
    cflags "-fsanitize-address-use-after-return=never" ; "-Wno-unused-command-line-argument"

  _ALL_SINGLE_KEYS_ ""
  _ALL_LIST_KEYS_ "cflags"
)

baker_cc_library_headers(
  name "libart_headers"
  defaults "art_defaults"
  host_supported ON
  export_include_dirs "."
  header_libs "art_libartbase_headers" ; "dlmalloc"
  export_header_lib_headers "art_libartbase_headers" ; "dlmalloc"
  apex_available "com.android.art" ; "com.android.art.debug"
  _target_ android
    header_libs "bionic_libc_platform_headers"
    export_header_lib_headers "bionic_libc_platform_headers"
  _target_ linux_bionic
    header_libs "bionic_libc_platform_headers"
    export_header_lib_headers "bionic_libc_platform_headers"

  _ALL_SINGLE_KEYS_ "host_supported"
  _ALL_LIST_KEYS_ "export_include_dirs" ; "apex_available" ; "defaults" ; "header_libs" ; "export_header_lib_headers"
)
...
```