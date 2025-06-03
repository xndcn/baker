function(baker_transform_source_file target SCOPE SOURCE_FILE)
    get_filename_component(file_name ${SOURCE_FILE} NAME_WE)
    get_filename_component(file_ext ${SOURCE_FILE} EXT)
    if(file_name MATCHES "\\*")
        file(GLOB_RECURSE file_list ${SOURCE_FILE})
        set(SOURCE_FILE ${file_list})
    elseif(file_name MATCHES "^:")
        # Convert ":file_name" to target link "file_name"
        string(SUBSTRING ${file_name} 1 -1 dependency)
        set(SOURCE_FILE "")
        target_link_libraries(${target} ${SCOPE} ${dependency}${file_ext})
    elseif(file_ext STREQUAL ".aidl")
        get_filename_component(dir_path ${SOURCE_FILE} DIRECTORY)
        file(RELATIVE_PATH dir_path "${CMAKE_CURRENT_SOURCE_DIR}" "${dir_path}")
        set(output_path ${CMAKE_CURRENT_BINARY_DIR}/gen/$<TARGET_PROPERTY:${target},_path>)
        set(output_file ${CMAKE_CURRENT_BINARY_DIR}/gen/${dir_path}/${file_name}.cpp)
        set(import_path ${CMAKE_CURRENT_SOURCE_DIR}/$<TARGET_PROPERTY:${target},_path>)
        # Run aidl on the .aidl file
        add_custom_command(
            OUTPUT ${output_file}
            COMMAND aidl --lang=cpp
                -h ${output_path}
                -o ${output_path}
                $<LIST:TRANSFORM,${import_path},PREPEND,-I>
                ${SOURCE_FILE}
            COMMAND_EXPAND_LISTS
        )
        set(SOURCE_FILE "${output_file}")
        target_include_directories(${target} ${SCOPE} ${output_path})
    elseif(file_ext STREQUAL ".yy")
        find_package(BISON)
        get_filename_component(file_path ${SOURCE_FILE} ABSOLUTE)
        # Run bison_target on the .yy file
        bison_target(${FILE_NAME}_parser ${file_path} "${CMAKE_CURRENT_BINARY_DIR}/${file_name}.cpp" DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/${file_name}.h)
        set(SOURCE_FILE ${BISON_${FILE_NAME}_parser_OUTPUTS})
        target_include_directories(${target} ${SCOPE} ${CMAKE_CURRENT_BINARY_DIR})
    elseif(file_ext STREQUAL ".ll")
        find_package(FLEX)
        get_filename_component(FILE_PATH ${SOURCE_FILE} ABSOLUTE)
        # Run flex_target on the .ll file
        flex_target(${file_name}_lexer ${FILE_PATH} "${CMAKE_CURRENT_BINARY_DIR}/${file_name}.cpp")
        set(SOURCE_FILE ${FLEX_${file_name}_lexer_OUTPUTS})
        target_include_directories(${target} ${SCOPE} ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    set(SOURCE_FILE "${SOURCE_FILE}" PARENT_SCOPE)
endfunction(baker_transform_source_file)

function(baker_apply_sources_transform target)
    get_target_property(private_sources ${target} SOURCES)
    if(private_sources STREQUAL "private_sources-NOTFOUND")
        set(private_sources "")
    endif()

    get_target_property(interface_sources ${target} INTERFACE_SOURCES)
    if(interface_sources STREQUAL "interface_sources-NOTFOUND")
        set(interface_sources "")
    endif()

    set(new_private_sources "")
    # Loop through all sources
    foreach(SOURCE_FILE ${private_sources})
        baker_transform_source_file(${target} PRIVATE ${SOURCE_FILE})
        list(APPEND new_private_sources ${SOURCE_FILE})
    endforeach()
    set(new_interface_sources "")
    foreach(SOURCE_FILE ${interface_sources})
        baker_transform_source_file(${target} INTERFACE ${SOURCE_FILE})
        list(APPEND new_interface_sources ${SOURCE_FILE})
    endforeach()

    get_target_property(imported ${target} IMPORTED)
    if(NOT imported)
        set_property(TARGET ${target} PROPERTY SOURCES ${new_private_sources})
    endif()
    set_property(TARGET ${target} PROPERTY INTERFACE_SOURCES ${new_interface_sources})
endfunction(baker_apply_sources_transform)


function(baker_filegroup)
    baker_parse_metadata(${ARGN})

    add_library(${name} INTERFACE)
    target_sources(${name} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${name})
endfunction()