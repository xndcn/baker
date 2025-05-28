function(get_all_targets_recursive output_var dir)
    get_property(targets DIRECTORY ${dir} PROPERTY BUILDSYSTEM_TARGETS)
    get_property(subdirs DIRECTORY ${dir} PROPERTY SUBDIRECTORIES)

    # Recursively process subdirectories
    foreach(subdir ${subdirs})
        get_all_targets_recursive(subdir_targets ${subdir})
        list(APPEND targets ${subdir_targets})
    endforeach()

    set(${output_var} ${targets} PARENT_SCOPE)
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