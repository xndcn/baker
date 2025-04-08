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
