function(baker_transform_tool_file TOOL_FILE)
    if(NOT IS_ABSOLUTE "${TOOL_FILE}")
        # Convert relative path to absolute path
        set(TOOL_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${TOOL_FILE}")
    endif()
    set(TOOL_FILE "${TOOL_FILE}" PARENT_SCOPE)
endfunction(baker_transform_tool_file)

function(baker_transform_tool TOOL)
    if(TOOL MATCHES "^:")
        # Convert ":tool" to target object of tool
        string(SUBSTRING ${TOOL} 1 -1 tool)
        set(TOOL "$<TARGET_FILE:${tool}>")
    endif()
    set(TOOL "${TOOL}" PARENT_SCOPE)
endfunction(baker_transform_tool)

function(baker_apply_genrule_transform target)
    # Transform cmd
    get_target_property(cmd ${target} _cmd)
    if(cmd STREQUAL "cmd-NOTFOUND")
        message(FATAL_ERROR "genrule '${target}' does not have a command.")
    endif()
    set(new_cmd "${cmd}")
    string(REPLACE "$(in)" "$\{in\}" new_cmd "${new_cmd}")
    string(REPLACE "$(out)" "$\{out\}" new_cmd "${new_cmd}")
    string(REPLACE "$(genDir)" "$\{genDir\}" new_cmd "${new_cmd}")
    set_property(TARGET ${target} PROPERTY _cmd "${new_cmd}")

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
    set_property(TARGET ${target} PROPERTY _tools ${new_tools})
endfunction(baker_apply_genrule_transform)