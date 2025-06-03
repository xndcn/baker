function(baker_get_all_targets_recursive output_var dir)
    get_property(targets DIRECTORY ${dir} PROPERTY BUILDSYSTEM_TARGETS)
    get_property(subdirs DIRECTORY ${dir} PROPERTY SUBDIRECTORIES)

    # Recursively process subdirectories
    foreach(subdir ${subdirs})
        baker_get_all_targets_recursive(subdir_targets ${subdir})
        list(APPEND targets ${subdir_targets})
    endforeach()

    set(${output_var} ${targets} PARENT_SCOPE)
endfunction()

# Parse arguments with repeated keywords
# Example: foo(BAR 1 2 3 BAR 4 5 6 _ANY_ 7) -> BAR=2, BAR0="1;2;3", BAR1="4;5;6", BAR_UNPARSED_ARGUMENTS="7"
function(baker_parse_repeated_arguments)
    cmake_parse_arguments(ARG "" "_KEY_" "" ${ARGN})
    if(NOT ARG__KEY_)
        message(FATAL_ERROR "_KEY_ must be specified")
    endif()
    set(remaining_args ${ARG_UNPARSED_ARGUMENTS})

    # Initialize counters
    set(count 0)
    set(index 0)
    set(values "")
    set(unparsed_args "")
    set(in_keyword_group FALSE)

    list(LENGTH remaining_args args_count)
    foreach(index RANGE ${args_count})
        list(GET remaining_args ${index} arg)
        # Check if current arg is a keyword
        if(arg STREQUAL ${ARG__KEY_})
            # Save previous values if any
            if(values)
                set(${ARG__KEY_}${count} "${values}" PARENT_SCOPE)
                math(EXPR count "${count} + 1")
            endif()
            set(values "")
            set(in_keyword_group TRUE)
        elseif(arg MATCHES "^_.*_$")
            # _*_ is a special keyword, exit
            list(SUBLIST remaining_args ${index} -1 remaining_args)
            list(APPEND unparsed_args ${remaining_args})
            break()
        else()
            if(in_keyword_group)
                list(APPEND values ${arg})
            else()
                list(APPEND unparsed_args ${arg})
            endif()
        endif()
    endforeach()

    # Handle the last keyword's values
    if(values)
        set(${ARG__KEY_}${count} "${values}" PARENT_SCOPE)
        math(EXPR count "${count} + 1")
    endif()

    # Set the count of keywords found
    set(${ARG__KEY_} ${count} PARENT_SCOPE)
    # Set unparsed arguments
    set(${ARG__KEY_}_UNPARSED_ARGUMENTS "${unparsed_args}" PARENT_SCOPE)
endfunction()


function(baker_python_binary_host)
    baker_parse_metadata(${ARGN})
    if(NOT ARG_stem)
        set(ARG_stem "${name}")
    endif()
    if(NOT ARG_suffix)
        set(ARG_suffix "")
    endif()

    add_executable(${name} IMPORTED GLOBAL)
    baker_parse_properties(${name})

    set(binary_name "${ARG_stem}${ARG_suffix}")
    set_target_properties(${name} PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/${binary_name}")
    file(
        GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${binary_name}
        INPUT ${CMAKE_SOURCE_DIR}/cmake/python_binary_host.template.sh
        TARGET ${name}
        USE_SOURCE_PERMISSIONS
    )
endfunction()