include(${CMAKE_CURRENT_LIST_DIR}/utils.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/aconfig.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/select.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/genrule.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/defaults.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cc.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/java.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/aidl.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/proto.cmake)

set(BAKER_DUMMY_C_SOURCE "${CMAKE_CURRENT_LIST_DIR}/dummy.c" CACHE FILEPATH "dummy.c" FORCE)

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
# Passing arguments cmd including special characters to macro
# may cause issues, so we have to use function here
function(baker_parse_metadata)
    # Parse conditions like target, arch, codegen
    set(unparsed_args ${ARGN})
    foreach(condition "target" "arch" "codegen")
        baker_parse_repeated_arguments(_KEY_ "_${condition}_" ${unparsed_args})
        set(unparsed_args ${_${condition}__UNPARSED_ARGUMENTS})
    endforeach()

    cmake_parse_arguments(ARG "" "name" "_ALL_SINGLE_KEYS_;_ALL_LIST_KEYS_;_ALL_EVAL_KEYS_" ${unparsed_args})
    if(NOT ARG_name)
        message(FATAL_ERROR "name must be specified")
    endif()
    get_directory_property(namespace _NAMESPACE_)
    if(NOT namespace STREQUAL "")
        set(ARG_name "${namespace}+${ARG_name}")
    endif()
    set(name ${ARG_name})
    cmake_parse_arguments(ARG "" "${ARG__ALL_SINGLE_KEYS_}" "${ARG__ALL_LIST_KEYS_}" ${ARG_UNPARSED_ARGUMENTS})

    foreach(condition "target" "arch" "codegen")
        if(${_${condition}_})
            math(EXPR range "${_${condition}_} - 1")
            foreach(index RANGE ${range})
                baker_parse_condition_properties(
                    _KEY_ ${condition}
                    _CONDITION_ ${_${condition}_${index}}
                )
                if(CONDITION_RESULT)
                    cmake_parse_arguments(COND "" "${ARG__ALL_SINGLE_KEYS_}" "${ARG__ALL_LIST_KEYS_}" ${CONDITION_PROPERTIES})
                    # Merge condition properties into the main arguments
                    foreach(key IN LISTS ARG__ALL_SINGLE_KEYS_)
                        if(DEFINED COND_${key})
                            set(ARG_${key} ${COND_${key}})
                        endif()
                    endforeach()
                    foreach(key IN LISTS ARG__ALL_LIST_KEYS_)
                        if(DEFINED COND_${key})
                            list(APPEND ARG_${key} ${COND_${key}})
                        endif()
                    endforeach()
                endif()
            endforeach()
        endif()
    endforeach()

    set(arg_ALL_SINGLE_KEYS "${ARG__ALL_SINGLE_KEYS_}")
    list(TRANSFORM arg_ALL_SINGLE_KEYS PREPEND "ARG_")
    set(arg_ALL_LIST_KEYS "${ARG__ALL_LIST_KEYS_}")
    list(TRANSFORM arg_ALL_LIST_KEYS PREPEND "ARG_")
    return(PROPAGATE name ARG_srcs ${arg_ALL_SINGLE_KEYS} ${arg_ALL_LIST_KEYS} ARG__ALL_SINGLE_KEYS_ ARG__ALL_LIST_KEYS_ ARG__ALL_EVAL_KEYS_ ARG_UNPARSED_ARGUMENTS)
endfunction()

function(baker_parse_condition_properties)
    cmake_parse_arguments(ARG "" "_KEY_" "_CONDITION_" ${ARGN})
    string(TOUPPER ${ARG__KEY_} condition_variable)
    # Split the key by underscores to get condition parts
    list(GET ARG__CONDITION_ 0 parts)
    list(REMOVE_AT ARG__CONDITION_ 0)

    set(conditions "")
    if(ARG__KEY_ STREQUAL "target")
        string(REPLACE "_" ";" parts "${parts}")
    endif()
    list(LENGTH parts count)
    set(index 0)
    set(CONDITION_RESULT TRUE)
    while(index LESS count)
        list(GET parts ${index} part)
        # Handle negated conditions (e.g., "not_windows" -> "NOT windows IN_LIST TARGET")
        if(part STREQUAL "not")
            math(EXPR index "${index} + 1") # Skip the next part
            list(GET parts ${index} next_part)
            if("${next_part}" IN_LIST ${condition_variable})
                set(CONDITION_RESULT FALSE)
                break()
            endif()
        else()
            if(NOT "${part}" IN_LIST ${condition_variable})
                set(CONDITION_RESULT FALSE)
                break()
            endif()
        endif()
        math(EXPR index "${index} + 1")
    endwhile()
    set(CONDITION_PROPERTIES ${ARG__CONDITION_})
    return(PROPAGATE CONDITION_RESULT CONDITION_PROPERTIES)
endfunction()

# Parse property keys and values
macro(baker_parse_properties target)
    foreach(key IN LISTS ARG__ALL_SINGLE_KEYS_)
        set_property(TARGET ${target} PROPERTY _${key} ${ARG_${key}})
    endforeach()
    foreach(key IN LISTS ARG__ALL_LIST_KEYS_)
        set_property(TARGET ${target} APPEND PROPERTY _${key} ${ARG_${key}})
    endforeach()
    list(TRANSFORM ARG__ALL_SINGLE_KEYS_ PREPEND _ OUTPUT_VARIABLE _ALL_SINGLE_KEYS_)
    set_property(TARGET ${target} PROPERTY _ALL_SINGLE_KEYS_ ${_ALL_SINGLE_KEYS_})
    list(TRANSFORM ARG__ALL_LIST_KEYS_ PREPEND _ OUTPUT_VARIABLE _ALL_LIST_KEYS_)
    set_property(TARGET ${target} PROPERTY _ALL_LIST_KEYS_ ${_ALL_LIST_KEYS_})
    list(TRANSFORM ARG__ALL_EVAL_KEYS_ PREPEND _ OUTPUT_VARIABLE _ALL_EVAL_KEYS_)
    set_property(TARGET ${target} PROPERTY _ALL_EVAL_KEYS_ ${_ALL_EVAL_KEYS_})
endmacro()

function(baker_soong_namespace)
    set_directory_properties(PROPERTIES _NAMESPACE_ "${PROJECT_NAME}")
endfunction(baker_soong_namespace)

function(baker_patch)
    baker_patch_defaults()
    baker_patch_eval()
endfunction()
