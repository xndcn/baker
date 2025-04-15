# Inherit properties from defaults
function(baker_inherit_defaults target)
    set(defaults_list ${ARGN})
    target_link_libraries(${target} INTERFACE ${defaults_list})
    foreach(default IN LISTS defaults_list)
        get_property(keys TARGET ${default} PROPERTY _ALL_KEYS_)
        foreach(key IN LISTS keys)
            get_property(value TARGET ${default} PROPERTY ${key})
            set_property(TARGET ${target} APPEND PROPERTY ${key} ${value})
        endforeach()
    endforeach()
endfunction()

# Apply defaults to a target with proper include directories and libraries
function(baker_apply_defaults target)
    set(defaults_list ${ARGN})
    target_link_libraries(${target} PRIVATE ${defaults_list})
    foreach(default IN LISTS defaults_list)
        baker_apply_properties(${target} ${default})
    endforeach()
endfunction()

function(baker_patch_inherit_defaults target)
    if(NOT TARGET ${target})
        message(WARNING "Target '${target}' does not exist. Skipping baker_patch_inherit_defaults.")
        # WARN: too much missing defaults, add dummy target here
        add_library(${target} INTERFACE)
    endif()
    # Check if defaults has already been patched
    get_property(is_patched TARGET ${target} PROPERTY __PATCHED SET)
    if(is_patched)
        return()
    endif()
    set_property(TARGET ${target} PROPERTY __PATCHED TRUE)

    # Get the dependencies of the defaults
    get_property(defaults TARGET ${target} PROPERTY _defaults)
    if (defaults)
        # Process each dependencies recursively
        foreach(depend ${defaults})
            baker_patch_inherit_defaults(${depend})
        endforeach()
        # Inherit defaults after all dependencies are processed
        baker_inherit_defaults(${target} ${defaults})
    endif()
endfunction()

# Patch all defaults, should be called after all defaults targets are created
function(baker_patch_defaults)
    get_all_targets_recursive(all_targets ${CMAKE_SOURCE_DIR})
    set(defaults_list "")
    # Get all defaults
    foreach(target ${all_targets})
        get_property(defaults TARGET ${target} PROPERTY _defaults)
        if(defaults)
            list(APPEND defaults_list ${defaults})
        endif()
    endforeach()
    list(REMOVE_DUPLICATES defaults_list)
    foreach(defaults ${defaults_list})
        baker_patch_inherit_defaults(${defaults})
    endforeach()
endfunction()