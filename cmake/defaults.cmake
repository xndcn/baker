# Inherit properties from defaults
function(baker_inherit_defaults target)
    set(defaults_list ${ARGN})
    target_link_libraries(${target} INTERFACE ${defaults_list})
    foreach(default IN LISTS defaults_list)
        if(NOT TARGET ${default})
            message(WARNING "Target '${default}' does not exist. Skipping inherit_defaults.")
            # WARN: too much missing defaults, add dummy target here
            add_library(${default} INTERFACE)
        else()
            get_property(keys TARGET ${default} PROPERTY _ALL_KEYS_)
            foreach(key IN LISTS keys)
                get_property(value TARGET ${default} PROPERTY ${key})
                set_property(TARGET ${target} APPEND PROPERTY ${key} ${value})
            endforeach()
        endif()
    endforeach()
endfunction()

function(baker_apply_properties target dependency)
    # Process include directories
    target_include_directories(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_include_dirs>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
    target_include_directories(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_local_include_dirs>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
    target_include_directories(${target} PUBLIC $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_include_dirs>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
    # Process header libraries
    target_link_libraries(${target} PRIVATE $<TARGET_PROPERTY:${dependency},_header_libs>)
    target_link_libraries(${target} PRIVATE $<TARGET_PROPERTY:${dependency},_header_lib_headers>)
    target_link_libraries(${target} PUBLIC $<TARGET_PROPERTY:${dependency},_export_header_libs>)
    target_link_libraries(${target} PUBLIC $<TARGET_PROPERTY:${dependency},_export_header_lib_headers>)
    # Process shared libraries
    target_link_libraries(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_shared_libs>,APPEND,-shared>)
    target_link_libraries(${target} PUBLIC $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_shared_libs>,APPEND,-shared>)
    # Process static libraries
    target_link_libraries(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_whole_static_libs>,APPEND,-static>)
    target_link_libraries(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_static_libs>,APPEND,-static>)
    target_link_libraries(${target} PUBLIC $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_whole_static_libs>,APPEND,-static>)
    target_link_libraries(${target} PUBLIC $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_static_libs>,APPEND,-static>)
    # Process cflags
    target_compile_options(${target} PRIVATE $<TARGET_PROPERTY:${dependency},_cflags>)
    # Linker flags
    target_link_options(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_linker_script>,PREPEND,-T${CMAKE_CURRENT_SOURCE_DIR}/>)
 endfunction(baker_apply_properties)

# Apply defaults to a target with proper include directories and libraries
function(baker_apply_defaults target)
    set(defaults_list ${ARGN})
    target_link_libraries(${target} PRIVATE ${defaults_list})
    foreach(default IN LISTS defaults_list)
        baker_apply_properties(${target} ${default})
   endforeach()
endfunction()
