include(${CMAKE_CURRENT_LIST_DIR}/sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/defaults.cmake)

function(baker dir)
    cmake_parse_arguments(BAKER "EXCLUDE_FROM_ALL" "OUTPUT" "" ${ARGN})

    if(SKIP_BAKER)
        message(STATUS "Skipping baker execution for ${dir} (SKIP_BAKER=ON)")
    else()
        message(STATUS "Processing Android.bp in ${dir}")

        set(baker_command baker "${dir}")
        # If OUTPUT is set, do not add recursive
        if(BAKER_OUTPUT)
            list(APPEND baker_command "--output" "${BAKER_OUTPUT}")
        else()
            list(APPEND baker_command "--recursive")
        endif()

        execute_process(
            COMMAND ${baker_command}
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

    # Check for custom output path or default location
    set(cmake_list_path "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/CMakeLists.txt")
    if(BAKER_OUTPUT)
        set(cmake_list_path "${CMAKE_CURRENT_SOURCE_DIR}/${BAKER_OUTPUT}")
    endif()

    if(EXISTS "${cmake_list_path}")
        if(IS_DIRECTORY "${dir}")
            message(STATUS "Adding subdirectory: ${dir}")
            if(BAKER_EXCLUDE_FROM_ALL)
                add_subdirectory(${dir} EXCLUDE_FROM_ALL)
            else()
                add_subdirectory(${dir})
            endif()
        endif()
    else()
        message(FATAL_ERROR "Failed to find CMakeLists.txt at ${cmake_list_path}")
    endif()
endfunction()

function(baker_include_build build)
    foreach(file ${build})
        # Process each file with baker function
        baker(${file} OUTPUT "${file}.cmake")

        # Include the generated cmake file
        include("${file}.cmake")
    endforeach()
endfunction()