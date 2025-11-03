function(baker_expand_source_files target file_list_var)
    set(new_sources "")
    get_target_property(source_dir ${target} SOURCE_DIR)
    foreach(source IN LISTS ${file_list_var})
        if(source MATCHES "\\*")
            # Check for double asterisk and remove it. GLOB_RECURSE already handles recursion
            string(REPLACE "**/" "" source "${source}")
            cmake_path(ABSOLUTE_PATH source BASE_DIRECTORY "${source_dir}")
            file(GLOB_RECURSE file_list ${source})
            set(source "${file_list}")
        endif()
        list(APPEND new_sources "${source}")
    endforeach()
    set(${file_list_var} "${new_sources}" PARENT_SCOPE)
endfunction()

function(baker_filegroup)
    baker_parse_metadata(${ARGN})

    add_library(${name} INTERFACE)
    baker_parse_properties(${name})
    # We need to append its sources directly to the target later
    set_property(TARGET ${name} PROPERTY _APPEND_SOURCES_ TRUE)
endfunction()


function(baker_transform_aidl_sources target sources_var)
    get_target_property(target_source_dir ${target} SOURCE_DIR)
    get_target_property(binary_dir ${target} BINARY_DIR)
    get_property(type TARGET ${target} PROPERTY TYPE)
    if(type STREQUAL "INTERFACE_LIBRARY")
        set(scope INTERFACE)
    else()
        set(scope PRIVATE)
    endif()

    # cpp
    add_library(.${target}.AIDL.CPP INTERFACE EXCLUDE_FROM_ALL)
    add_custom_target(.${target}.GEN.AIDL.CPP)
    add_dependencies(.${target}.AIDL.CPP .${target}.GEN.AIDL.CPP)
    # java
    add_library(.${target}.AIDL.JAVA INTERFACE EXCLUDE_FROM_ALL)
    add_custom_target(.${target}.GEN.AIDL.JAVA)
    add_dependencies(.${target}.AIDL.JAVA .${target}.GEN.AIDL.JAVA)

    foreach(source IN LISTS ${sources_var})
        get_property(source_dir SOURCE ${source} PROPERTY _BASE_DIR_)
        if(NOT source_dir)
            set(source_dir "${target_source_dir}")
        endif()
        get_filename_component(dir_path ${source} DIRECTORY)
        get_filename_component(file_name ${source} NAME_WE)
        get_property(path SOURCE ${source} PROPERTY _path)
        file(RELATIVE_PATH dir_path "${source_dir}" "${dir_path}")
        set(output_path "${binary_dir}/gen/${target}/${path}/")
        set(import_path "${source_dir}/${path}/")
        # cpp
        set(output_file ${binary_dir}/gen/${target}/${dir_path}/${file_name}.cpp)
        # Run aidl on the .aidl file
        add_custom_command(
            OUTPUT ${output_file}
            COMMAND aidl --lang=cpp
                -h ${output_path}
                -o ${output_path}
                $<LIST:TRANSFORM,${import_path},PREPEND,-I>
                ${source}
            COMMAND_EXPAND_LISTS
        )
        set_property(TARGET .${target}.GEN.AIDL.CPP APPEND PROPERTY SOURCES ${output_file})
        target_sources(.${target}.AIDL.CPP INTERFACE ${output_file})
        target_include_directories(.${target}.AIDL.CPP INTERFACE ${output_path})
        target_link_libraries(${target} ${scope} $<$<LINK_LANGUAGE:CXX>:.${target}.AIDL.CPP>)

        # java
        set(output_file ${binary_dir}/gen/${target}/${dir_path}/${file_name}.java)
        add_custom_command(
            OUTPUT ${output_file}
            COMMAND aidl --lang=java
                -o ${output_path}
                $<LIST:TRANSFORM,${import_path},PREPEND,-I>
                ${source}
            COMMAND_EXPAND_LISTS
        )
        set_property(TARGET .${target}.GEN.AIDL.JAVA APPEND PROPERTY SOURCES ${output_file})
        target_sources(.${target}.AIDL.JAVA INTERFACE ${output_file})
        target_link_libraries(${target} ${scope} $<$<LINK_LANGUAGE:JAVA>:.${target}.AIDL.JAVA>)
    endforeach()
endfunction()

function(baker_transform_source_files target sources_var)
    set(new_srcs "")
    get_target_property(binary_dir ${target} BINARY_DIR)
    get_target_property(source_dir ${target} SOURCE_DIR)
    get_property(type TARGET ${target} PROPERTY TYPE)
    if(type STREQUAL "INTERFACE_LIBRARY")
        set(scope INTERFACE)
    else()
        set(scope PRIVATE)
    endif()

    set(aidl_srcs "")
    baker_contains_property(need_aidl_transform ${target} "aidl_*")
    set(proto_srcs "")
    baker_contains_property(need_proto_transform ${target} "proto_*")

    foreach(source IN LISTS ${sources_var})
        if(source STREQUAL "")
            continue()
        endif()
        get_filename_component(file_name ${source} NAME_WE)
        get_filename_component(file_ext ${source} EXT)
        if(file_ext STREQUAL ".yy")
            find_package(BISON)
            # Run bison_target on the .yy file
            bison_target(${file_name}_parser ${source} "${binary_dir}/${file_name}.cpp" DEFINES_FILE ${binary_dir}/${file_name}.h)
            set(source ${BISON_${file_name}_parser_OUTPUTS})
            target_include_directories(${target} ${scope} ${binary_dir})
            add_custom_target(${file_name}_parser DEPENDS ${BISON_${file_name}_parser_OUTPUTS})
            add_dependencies(${target} ${file_name}_parser)
        elseif(file_ext STREQUAL ".ll")
            find_package(FLEX)
            # Run flex_target on the .ll file
            flex_target(${file_name}_lexer ${source} "${binary_dir}/${file_name}.cpp")
            set(source ${FLEX_${file_name}_lexer_OUTPUTS})
            target_include_directories(${target} ${scope} ${binary_dir})
            add_custom_target(${file_name}_lexer DEPENDS ${FLEX_${file_name}_lexer_OUTPUTS})
            add_dependencies(${target} ${file_name}_lexer)
        elseif(file_ext STREQUAL ".aidl" AND need_aidl_transform)
            list(APPEND aidl_srcs "${source}")
            set(source "")
        elseif(file_ext STREQUAL ".proto" AND need_proto_transform)
            list(APPEND proto_srcs "${source}")
            set(source "")
        endif()
        list(APPEND new_srcs "${source}")
    endforeach()

    # Handle AIDL files
    if(need_aidl_transform AND aidl_srcs)
        baker_transform_aidl_sources(${target} aidl_srcs)
    endif()
    # Handle Proto files
    if(need_proto_transform AND proto_srcs)
        if(scope STREQUAL "PRIVATE")
            set_property(TARGET ${target} APPEND PROPERTY _PROTO_SOURCES_ ${proto_srcs})
        else()
            set_property(TARGET ${target} APPEND PROPERTY INTERFACE__PROTO_SOURCES_ ${proto_srcs})
        endif()
        set_property(TARGET ${target} APPEND PROPERTY TRANSITIVE_COMPILE_PROPERTIES "_PROTO_SOURCES_")
        baker_transform_protos(proto_srcs TARGET ${target} SCOPE ${scope})
    endif()
    set(${sources_var} "${new_srcs}" PARENT_SCOPE)
endfunction()

function(baker_patch_srcs_recursive_sources target sources_var)
    get_property(type TARGET ${target} PROPERTY TYPE)
    if(type STREQUAL "INTERFACE_LIBRARY")
        set(scope INTERFACE)
    else()
        set(scope PRIVATE)
    endif()

    set(new_srcs "")
    get_target_property(source_dir ${target} SOURCE_DIR)
    foreach(source IN LISTS ${sources_var})
        baker_canonicalize_name(source "${source}")
        if(source MATCHES "^//.*:.*")
            # Convert "//visibility:name" to target link "name"
            # TODO: handle visibility
            string(REGEX MATCH "^//(.*):(.*)" _match "${source}")
            set(visibility "${CMAKE_MATCH_1}")
            set(source ":${CMAKE_MATCH_2}")
        endif()
        if(NOT source MATCHES "^:")
            if(IS_ABSOLUTE "${source}")
                list(APPEND new_srcs "${source}")
            else()
                list(APPEND new_srcs "${source_dir}/${source}")
            endif()
        else()
            string(SUBSTRING ${source} 1 -1 dependency)
            # Check if dependency is a target
            if(NOT TARGET ${dependency})
                message(WARNING "Target '${target}' has source '${dependency}' which is not a valid target.")
                continue()
            endif()
            baker_patch_sources(${dependency})
            # Link the dependency target if it do not need to append sources, hence not a filegroup or genrule
            get_property(append TARGET ${dependency} PROPERTY _APPEND_SOURCES_)
            if(NOT append)
                target_link_libraries(${target} ${scope} ${dependency})
            else()
                get_property(dependency_sources TARGET ${dependency} PROPERTY INTERFACE_SOURCES)
                list(APPEND new_srcs "${dependency_sources}")
            endif()
            add_dependencies(${target} ${dependency})
        endif()
    endforeach()
    set(${sources_var} "${new_srcs}" PARENT_SCOPE)
endfunction()

function(baker_patch_srcs_recursive target)
    # Check if target has already been patched
    get_property(is_patched TARGET ${target} PROPERTY _SRCS_PATCHED_ SET)
    if(is_patched)
        return()
    endif()

    set_property(TARGET ${target} PROPERTY _SRCS_PATCHED_ TRUE)

    get_property(srcs TARGET ${target} PROPERTY _srcs SET)
    if(NOT srcs)
        return()
    endif()

    get_target_property(source_dir ${target} SOURCE_DIR)
    get_property(sources TARGET ${target} PROPERTY _srcs)
    baker_expand_source_files(${target} sources)
    get_property(path TARGET ${target} PROPERTY _path)
    foreach(source IN LISTS sources)
        cmake_path(ABSOLUTE_PATH source BASE_DIRECTORY "${source_dir}")
        # Add path property to each source file if exists
        # See filegroup.go:Path
        if(DEFINED path)
            set_property(SOURCE ${source} PROPERTY _path "${path}")
        endif()
        # TODO: consider multi target contains the same source file
        set_property(SOURCE ${source} PROPERTY _BASE_DIR_ "${source_dir}")
    endforeach()
    baker_patch_srcs_recursive_sources(${target} sources)
    get_property(exclude_sources TARGET ${target} PROPERTY _exclude_srcs)
    baker_patch_srcs_recursive_sources(${target} exclude_sources)
    baker_expand_source_files(${target} exclude_sources)
    # Merge srcs and exclude_srcs
    list(REMOVE_ITEM sources ${exclude_sources})
    # Apply source file transformations
    baker_transform_source_files(${target} sources)

    get_property(type TARGET ${target} PROPERTY TYPE)
    # Append collected sources to the target
    if(type STREQUAL "INTERFACE_LIBRARY")
        set_property(TARGET ${target} APPEND PROPERTY INTERFACE_SOURCES "${sources}")
    else()
        # Check if target do not have any source file
        if(sources STREQUAL "")
            message(WARNING "Target '${target}' has no source file after patching. Adding a dummy source file to avoid CMake error.")
            # Add a dummy source file to avoid CMake error
            list(APPEND sources "${BAKER_DUMMY_C_SOURCE}")
        endif()
        set_property(TARGET ${target} APPEND PROPERTY SOURCES "${sources}")
    endif()
endfunction()


function(baker_patch_sources target)
    # Patch srcs recursively
    baker_patch_srcs_recursive(${target})
    # target maybe a genrule, patch its outputs as well
    baker_patch_genrule(${target})
endfunction()

function(baker_patch_srcs)
    baker_get_all_targets_recursive(all_targets ${CMAKE_SOURCE_DIR})
    foreach(target ${all_targets})
        baker_patch_sources(${target})
    endforeach()
endfunction()