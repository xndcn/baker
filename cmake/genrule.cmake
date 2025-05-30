function(baker_transform_tool_file TOOL_FILE)
    if(TOOL_FILE MATCHES "^:")
        # Convert ":tool_file" to target sources of tool_file
        string(SUBSTRING ${TOOL_FILE} 1 -1 TOOL_FILE)
        set(TOOL_FILE "$<TARGET_PROPERTY:${TOOL_FILE},INTERFACE_SOURCES>")
    elseif(NOT IS_ABSOLUTE "${TOOL_FILE}")
        set(TOOL_FILE "./${TOOL_FILE}")
    endif()
    set(TOOL_FILE "${TOOL_FILE}" PARENT_SCOPE)
endfunction(baker_transform_tool_file)

function(baker_transform_tool TOOL)
    if(TOOL MATCHES "^:")
        # Convert ":tool" to target object of tool
        string(SUBSTRING ${TOOL} 1 -1 TOOL)
    endif()
    set(TOOL "$<IF:$<TARGET_EXISTS:${TOOL}>,$<TARGET_FILE:${TOOL}>,${TOOL}>")
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
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_parse_properties(${src})
    baker_apply_genrule_transform(${src})

    set(command_file "${CMAKE_CURRENT_BINARY_DIR}/${name}.genrule.sh")
    file(GENERATE OUTPUT "${command_file}" INPUT "${CMAKE_SOURCE_DIR}/cmake/genrule.template.sh" TARGET ${src})
    add_custom_command(
        OUTPUT "$<LIST:TRANSFORM,${ARG_out},PREPEND,${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/>"
        COMMAND ${command_file} ARGS
            --genDir "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/"
            --outs "$<GENEX_EVAL:$<TARGET_PROPERTY:${src},_out>>"
            --srcs "$<PATH:RELATIVE_PATH,$<TARGET_PROPERTY:${src},INTERFACE_SOURCES>,${CMAKE_CURRENT_SOURCE_DIR}>"
            --tools "$<GENEX_EVAL:$<TARGET_PROPERTY:${src},_tools>>"
            --tool_files "$<GENEX_EVAL:$<TARGET_PROPERTY:${src},_tool_files>>"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS $<GENEX_EVAL:$<TARGET_PROPERTY:${src},_tools>> ; $<GENEX_EVAL:$<TARGET_PROPERTY:${src},_tool_files>> ; $<TARGET_PROPERTY:${src},INTERFACE_LINK_LIBRARIES>
        VERBATIM
    )
    add_custom_target(.${name}.DEP SOURCES "$<LIST:TRANSFORM,${ARG_out},PREPEND,${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/>")

    add_library(${name} OBJECT ".")
    set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
    target_sources(${name} INTERFACE "$<LIST:TRANSFORM,${ARG_out},PREPEND,${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/>")
    add_dependencies(${name} .${name}.DEP)
    # generated_headers expects the output directory to be in the include path
    target_include_directories(${name} INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/)
    return(PROPAGATE name)
endfunction()

function(baker_gensrcs)
    baker_parse_metadata(${ARGN})

    list(APPEND ARG__ALL_LIST_KEYS_ "out")
    set(ARG_out "$<PATH:REPLACE_EXTENSION,${ARG_srcs},.${ARG_output_extension}>")
    set(args "")
    foreach(key IN LISTS ARG__ALL_SINGLE_KEYS_)
        list(APPEND args "${key}" "${ARG_${key}}")
    endforeach()
    foreach(key IN LISTS ARG__ALL_LIST_KEYS_)
        list(APPEND args "${key}" "${ARG_${key}}")
    endforeach()
    baker_genrule(
        name ${name}
        srcs ${ARG_srcs}
        ${args}
        _ALL_SINGLE_KEYS_ ${ARG__ALL_SINGLE_KEYS_}
        _ALL_LIST_KEYS_ ${ARG__ALL_LIST_KEYS_}
    )
endfunction()