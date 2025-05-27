include(${CMAKE_CURRENT_LIST_DIR}/utils.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/aconfig.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/select.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/genrule.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/defaults.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cc.cmake)

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
        if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${dir}")
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

function(baker_include_build)
    set(BUILD ${ARGN})
    foreach(file ${build})
        # Process each file with baker function
        baker(${file} OUTPUT "${file}.cmake")

        # Include the generated cmake file
        include("${file}.cmake")
    endforeach()
endfunction()

# Parse basic metadata
macro(baker_parse_metadata)
    cmake_parse_arguments(ARG "" "name" "_ALL_SINGLE_KEYS_;_ALL_LIST_KEYS_" ${ARGN})
    if(NOT ARG_name)
        message(FATAL_ERROR "name must be specified")
    endif()
    set(name ${ARG_name})
    cmake_parse_arguments(ARG "" "${ARG__ALL_SINGLE_KEYS_}" "srcs;${ARG__ALL_LIST_KEYS_}" ${ARG_UNPARSED_ARGUMENTS})
endmacro()

# Parse property keys and values
macro(baker_parse_properties target)
    foreach(key IN LISTS ARG__ALL_SINGLE_KEYS_)
        set_property(TARGET ${target} PROPERTY _${key} ${ARG_${key}})
    endforeach()
    foreach(key IN LISTS ARG__ALL_LIST_KEYS_)
        set_property(TARGET ${target} APPEND PROPERTY _${key} ${ARG_${key}})
    endforeach()
    list(TRANSFORM ARG__ALL_SINGLE_KEYS_ PREPEND _)
    set_property(TARGET ${target} PROPERTY _ALL_SINGLE_KEYS_ ${ARG__ALL_SINGLE_KEYS_})
    list(TRANSFORM ARG__ALL_LIST_KEYS_ PREPEND _)
    set_property(TARGET ${target} PROPERTY _ALL_LIST_KEYS_ ${ARG__ALL_LIST_KEYS_})
endmacro()