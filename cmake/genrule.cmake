function(baker_transform_tool_file TOOL_FILE)
    if(TOOL_FILE MATCHES "^:")
        # Convert ":tool_file" to target sources of tool_file
        string(SUBSTRING ${TOOL_FILE} 1 -1 TOOL_FILE)
        set(TOOL_FILE "$<TARGET_PROPERTY:${TOOL_FILE},INTERFACE_SOURCES>")
    elseif(NOT IS_ABSOLUTE "${TOOL_FILE}")
        set(TOOL_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${TOOL_FILE}")
    endif()
    set(TOOL_FILE "${TOOL_FILE}" PARENT_SCOPE)
endfunction(baker_transform_tool_file)

function(baker_transform_tool TOOL)
    if(TOOL MATCHES "^:")
        # Convert ":tool" to target object of tool
        string(SUBSTRING ${TOOL} 1 -1 TOOL)
    endif()
    set(TOOL "$<IF:$<TARGET_EXISTS:${TOOL}>,$<TARGET_FILE:${TOOL}>,${CMAKE_CURRENT_SOURCE_DIR}/${TOOL}>")
    set(TOOL "${TOOL}" PARENT_SCOPE)
endfunction(baker_transform_tool)

function(baker_apply_genrule_transform target)
    # Transform tool_files
    get_target_property(tool_files ${target} _tool_files)
    if(tool_files STREQUAL "tool_files-NOTFOUND")
        set(tool_files "")
    endif()
    set(new_tool_files "")
    foreach(TOOL_FILE ${tool_files})
        baker_transform_tool_file(${TOOL_FILE})
        list(APPEND new_tool_files ${TOOL_FILE})
    endforeach()
    set_property(TARGET ${target} PROPERTY _tool_files "${new_tool_files}")

    # Transform tools
    get_target_property(tools ${target} _tools)
    if(tools STREQUAL "tools-NOTFOUND")
        set(tools "")
    endif()
    set(new_tools "")
    foreach(TOOL ${tools})
        baker_transform_tool(${TOOL})
        list(APPEND new_tools ${TOOL})
    endforeach()
    set_property(TARGET ${target} PROPERTY _tools "${new_tools}")
endfunction(baker_apply_genrule_transform)


function(baker_genrule)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    baker_apply_genrule_transform(${src})

    add_library(${name} OBJECT ".")
    set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
    # generated_headers expects the output directory to be in the include path
    target_include_directories(${name} INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/)
    set_target_properties(${name} PROPERTIES
        _GENRULE_PATCHED_ FALSE
        _GENRULE_SRC_ "${src}"
        _APPEND_SOURCES_ TRUE
    )
    return(PROPAGATE name)
endfunction()

function(baker_gensrcs)
    baker_genrule(${ARGN})
endfunction()


function(baker_genrule_patch_sources name)
    get_target_property(source_dir ${name} SOURCE_DIR)
    get_target_property(binary_dir ${name} BINARY_DIR)

    get_target_property(src ${name} _GENRULE_SRC_)
    baker_patch_sources(${src})
    get_property(sources TARGET ${src} PROPERTY INTERFACE_SOURCES)

    get_property(out TARGET ${src} PROPERTY _out)
    get_property(output_extension TARGET ${src} PROPERTY _output_extension)
    # gensrcs
    if(NOT DEFINED out AND NOT output_extension STREQUAL "")
        set(out "")
        foreach(source IN LISTS sources)
            cmake_path(RELATIVE_PATH source BASE_DIRECTORY "${source_dir}")
            cmake_path(REPLACE_EXTENSION source .${output_extension})
            list(APPEND out ${source})
        endforeach()

        set_property(TARGET ${src} PROPERTY _out "${out}")
        set_property(TARGET ${src} APPEND PROPERTY ARG__ALL_LIST_KEYS_ "out")
    endif()

    set(command_file "${binary_dir}/${name}.genrule.sh")
    file(GENERATE OUTPUT "${command_file}" INPUT "${CMAKE_SOURCE_DIR}/cmake/genrule.template.sh" TARGET ${src})
    list(TRANSFORM out PREPEND "${binary_dir}/gen/${name}/" OUTPUT_VARIABLE outputs)
    add_custom_command(
        OUTPUT ${outputs}
        COMMAND ${command_file} ARGS
            --genDir "${binary_dir}/gen/${name}/"
            --outs "$<GENEX_EVAL:$<TARGET_PROPERTY:${src},_out>>"
            --tools "$<GENEX_EVAL:$<TARGET_PROPERTY:${src},_tools>>"
            --tool_files "$<GENEX_EVAL:$<TARGET_PROPERTY:${src},_tool_files>>"
        WORKING_DIRECTORY ${source_dir}
        # Avoid too long command line
        COMMENT "Generating sources for genrule ${name}"
        DEPENDS ${src} ; $<GENEX_EVAL:$<TARGET_PROPERTY:${src},_tools>> ; $<GENEX_EVAL:$<TARGET_PROPERTY:${src},_tool_files>>
        VERBATIM
    )
    add_custom_target(.${name}.DEP DEPENDS "${outputs}")
    target_sources(${name} INTERFACE "${outputs}")
    add_dependencies(${name} .${name}.DEP)
endfunction()

function(baker_patch_genrule target)
    get_property(is_genrule_patched TARGET ${target} PROPERTY _GENRULE_PATCHED_)
    if(is_genrule_patched STREQUAL "FALSE")
        set_target_properties(${target} PROPERTIES _GENRULE_PATCHED_ TRUE)
        baker_genrule_patch_sources(${target})
    endif()
endfunction()