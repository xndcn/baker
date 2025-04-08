# Inherit properties from defaults
function(inherit_defaults target)
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
function(apply_defaults target)
    set(defaults_list ${ARGN})
    target_link_libraries(${target} PRIVATE ${defaults_list})
    foreach(default IN LISTS defaults_list)
        # Process include directories
        target_include_directories(${target} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/$<TARGET_PROPERTY:${default},_include_dirs>)
        target_include_directories(${target} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/$<TARGET_PROPERTY:${default},_local_include_dirs>)
        target_include_directories(${target} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/$<TARGET_PROPERTY:${default},_export_include_dirs>)
        # Process header libraries
        target_link_libraries(${target} PRIVATE $<TARGET_PROPERTY:${default},_header_libs>)
        target_link_libraries(${target} PRIVATE $<TARGET_PROPERTY:${default},_header_lib_headers>)
        target_link_libraries(${target} PUBLIC $<TARGET_PROPERTY:${default},_export_header_libs>)
        target_link_libraries(${target} PUBLIC $<TARGET_PROPERTY:${default},_export_header_lib_headers>)
        # Process shared libraries
        target_link_libraries(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${default},_shared_libs>,APPEND,-shared>)
        target_link_libraries(${target} PUBLIC $<LIST:TRANSFORM,$<TARGET_PROPERTY:${default},_export_shared_libs>,APPEND,-shared>)
        # Process static libraries
        target_link_libraries(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${default},_whole_static_libs>,APPEND,-static>)
        target_link_libraries(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${default},_static_libs>,APPEND,-static>)
        target_link_libraries(${target} PUBLIC $<LIST:TRANSFORM,$<TARGET_PROPERTY:${default},_export_whole_static_libs>,APPEND,-static>)
        target_link_libraries(${target} PUBLIC $<LIST:TRANSFORM,$<TARGET_PROPERTY:${default},_export_static_libs>,APPEND,-static>)
        # Process cflags
        target_compile_options(${target} PRIVATE $<TARGET_PROPERTY:${default},_cflags>)
    endforeach()
endfunction()
