add_library(.BAKER_OBJECTS INTERFACE)
set_target_properties(.BAKER_OBJECTS PROPERTIES _targets "")

function(baker_add_cc_object name)
    set_property(TARGET .BAKER_OBJECTS APPEND PROPERTY _targets "${name}")
endfunction()

function(baker_add_cc_object_impl name)
    get_property(defaults_list TARGET .${name}.OBJ PROPERTY _defaults)
    if(defaults_list)
        baker_inherit_defaults(.${name}.OBJ ${defaults_list})
    endif(defaults_list)

    get_target_property(linker_script .${name}.OBJ _linker_script)
    if(linker_script STREQUAL "linker_script-NOTFOUND")
        add_library(${name} OBJECT $<TARGET_OBJECTS:.${name}.OBJ>)
    else()
        # cc_object with linker_script is one object by partial linking of multiple object files
        add_executable(${name} $<TARGET_OBJECTS:.${name}.OBJ>)
        # Always enable position independent code
        set_target_properties(${name} PROPERTIES POSITION_INDEPENDENT_CODE ON)
        set_target_properties(${name} PROPERTIES SUFFIX .o ENABLE_EXPORTS ON)
        # Set the linker to use the partial linking option
        target_link_options(${name} PRIVATE "-no-pie" "-nostdlib" "-Wl,-r")
        target_link_libraries(${name} INTERFACE "$<TARGET_FILE:${name}>")
        target_link_options(${name} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:.${name}.OBJ,_linker_script>,PREPEND,-T$<TARGET_PROPERTY:.${name}.OBJ,SOURCE_DIR>/>)
    endif()
endfunction()

function(baker_patch_cc_object)
    get_property(targets TARGET .BAKER_OBJECTS PROPERTY _targets)
    foreach(target IN LISTS targets)
        baker_add_cc_object_impl(${target})
    endforeach()
endfunction()