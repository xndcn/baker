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