cmake_minimum_required(VERSION 3.28)
# set_tests_properties with DIRECTORY requires CMake 3.28
project(BakerTest)

# Set C++20 as the standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add linker flag to fail if symbols are missing in shared libraries
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")

# Add option to skip baker execution
option(SKIP_BAKER "Skip execution of baker command" OFF)

include(CTest)
include(cmake/defaults.cmake)

include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/releases/download/v1.16.0/googletest-1.16.0.tar.gz
  DOWNLOAD_EXTRACT_TIMESTAMP FALSE
)
FetchContent_MakeAvailable(googletest)
# Add alias for gtest and gmock
add_library(libgmock-static ALIAS gmock)
add_library(libgtest-static ALIAS gtest)
add_library(libgtest_main-static ALIAS gtest_main)

function(baker dir)
    if(SKIP_BAKER)
        message(STATUS "Skipping baker execution for ${dir} (SKIP_BAKER=ON)")
    else()
        message(STATUS "Processing Android.bp in ${dir}")
        execute_process(
            COMMAND baker "${dir}" "--recursive"
            RESULT_VARIABLE baker_result
            OUTPUT_VARIABLE baker_output
            ERROR_VARIABLE baker_error
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        )

        if(baker_result EQUAL 0)
            message(STATUS "Successfully converted blueprint in ${dir}")
        else()
            message(FATAL_ERROR "Failed to convert blueprint in ${dir}: ${baker_error}")
        endif()
    endif()

    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/CMakeLists.txt")
        message(STATUS "Adding subdirectory: ${dir}")
        add_subdirectory(${dir})
    else()
        message(FATAL_ERROR "Failed to add subdirectory ${dir}")
    endif()
endfunction()

baker(external/fmtlib/)

# fmtlib_test_2 will fail because the locale problem
set_tests_properties(fmtlib_test_2 DIRECTORY external/fmtlib/ PROPERTIES WILL_FAIL TRUE)

# Remove googletest includes from fmtlib-test-defaults
get_property(old_includes TARGET fmtlib-test-defaults PROPERTY _include_dirs)
set(new_includes)
foreach(dir ${old_includes})
    if(NOT dir MATCHES "external/googletest/googletest/include/gtest")
        list(APPEND new_includes ${dir})
    endif()
endforeach()
set_property(TARGET fmtlib-test-defaults PROPERTY _include_dirs ${new_includes})