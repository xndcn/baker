function(baker_aidl_interface)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    set(ARG_srcs "")

    # TODO: support versions in defaults
    set(versions "")
    set(version_imports "")
    if(DEFINED ARG_versions)
        foreach(version IN LISTS ARG_versions)
            list(APPEND versions ${version})
            list(APPEND version_imports "$<TARGET_PROPERTY:${src},_imports>")
            math(EXPR next_version "1 + ${version}")
        endforeach()
    elseif(DEFINED ARG_versions_with_info)
        foreach(version_info IN LISTS ARG_versions_with_info)
            string(JSON version GET ${version_info} version)
            string(JSON imports GET ${version_info} imports)
            list(APPEND versions ${version})
            list(APPEND version_imports ${imports})
            math(EXPR next_version "1 + ${version}")
        endforeach()
    endif()
    list(APPEND versions "<dummy>") # Add a dummy version since cmake does not support lists with empty elements
    list(APPEND version_imports "$<TARGET_PROPERTY:${src},_imports>")

    list(LENGTH versions version_count)
    foreach(version imports IN ZIP_LISTS versions version_imports)
        set(lib "${name}")
        set(args "")
        if(NOT version STREQUAL "<dummy>")
            set(lib "${name}-V${version}")
            list(APPEND args --version ${version})

            # For aidl with version, use the aidl_api directory to find the sources
            file(GLOB_RECURSE lib_sources RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}/aidl_api/${name}/${version}/" "aidl_api/${name}/${version}/*.aidl")
            add_library(${lib} OBJECT)
        else()
            if(version_count GREATER 1)
                set(lib "${name}-V${next_version}")
                set(version "${next_version}")
                list(APPEND args --version ${next_version} --current)
            endif()
            set(lib_sources "")
            add_library(${lib} OBJECT)
        endif()
        set_target_properties(${lib} PROPERTIES LINKER_LANGUAGE CXX _name ${name})
        target_link_libraries(${lib} PRIVATE ${src})
        target_link_libraries(${lib} PRIVATE ${version_imports})
        # Add properties to ${lib}
        baker_parse_properties(${lib})

        file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${lib}.aidl.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/aidl.template.sh" TARGET ${lib})
        add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/gen/${lib}.preprocessed.aidl"
            COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${lib}.aidl.sh
                --preprocess --output ${CMAKE_CURRENT_BINARY_DIR}/gen/ ${args}
            DEPENDS aidl ${version_imports}
        )
        add_custom_target(.${lib}.DEP SOURCES "${CMAKE_CURRENT_BINARY_DIR}/gen/${lib}.preprocessed.aidl")
        add_dependencies(${lib} .${lib}.DEP)
        set_target_properties(${lib} PROPERTIES INTERFACE__PREPROCESSED_AIDL_ "${CMAKE_CURRENT_BINARY_DIR}/gen/${lib}.preprocessed.aidl")
        set_target_properties(${lib} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_PREPROCESSED_AIDL_")

        # backend: cpp
        set(_BACKUP_name_ ${name})
        baker_cc_library(
            name ${lib}-cpp
            # no sources need to do transform, add outputs later
            srcs ""
            # aidl_interface should link to libbinder
            export_shared_libs "libbinder"
            # NOTE: Seems libbinder does not support RTTI, so we disable it here
            cflags "-fno-rtti"
            _ALL_SINGLE_KEYS_ ""
            _ALL_LIST_KEYS_ "export_shared_libs" "cflags"
        )
        # Restore the original name after calling baker_cc_library
        set(name ${_BACKUP_name_})
        add_library(${lib}-cpp-headers INTERFACE)
        target_include_directories(${lib}-cpp-headers INTERFACE "${CMAKE_CURRENT_BINARY_DIR}/gen/${lib}-cpp-source/include/")
        target_link_libraries(${lib}-cpp-headers INTERFACE "$<LIST:TRANSFORM,${imports},APPEND,-cpp-headers>")
        add_custom_target(.${lib}-cpp.DEP DEPENDS "$<LIST:TRANSFORM,${imports},APPEND,-cpp-source>")
        add_dependencies(.${lib}-cpp.OBJ .${lib}-cpp.DEP)
        target_link_libraries(.${lib}-cpp.OBJ PUBLIC ${lib}-cpp-headers)
        target_link_libraries(${lib}-cpp-static PUBLIC ${lib}-cpp-headers "$<LIST:TRANSFORM,${imports},APPEND,-cpp-static>")
        target_link_libraries(${lib}-cpp-shared PUBLIC ${lib}-cpp-headers "$<LIST:TRANSFORM,${imports},APPEND,-cpp-shared>")

        # backend: java
        # TODO: support sdk_version in defaults
        set(sdk_version "${ARG_backend_java_sdk_version}")
        set(platform_apis "${ARG_backend_java_platform_apis}")
        if(NOT ARG_backend_java_platform_apis OR ARG_backend_java_platform_apis STREQUAL "")
            set(platform_apis FALSE)
        endif()
        if(sdk_version STREQUAL "" AND NOT platform_apis)
            set(sdk_version "system_current")
        endif()
        baker_java_library(
            name ${lib}-java
            srcs ""
            sdk_version ${sdk_version}
            is_stubs_module TRUE
            _ALL_SINGLE_KEYS_ "is_stubs_module;sdk_version"
            _ALL_LIST_KEYS_ ""
        )
        target_link_libraries(.${lib}-java.SRC PRIVATE "$<LIST:TRANSFORM,${imports},APPEND,-java>")
        add_dependencies(${lib}-java ${lib}-java-source)

        if(lib_sources)
            baker_aidl_interface_patch_sources(${lib} "${lib_sources}" "${version_imports}" "${args}")
        else()
            # For the non-versioned aidl, we can not determine the sources, patch it later
            set_target_properties(${lib} PROPERTIES
                _AIDL_PATCHED_ FALSE
                _AIDL_SRC_ "${src}"
                _AIDL_VERSION_IMPORTS_ "${version_imports}"
                _AIDL_ARGS_ "${args}"
            )
        endif()
    endforeach()
endfunction()

function(baker_aidl_interface_patch_sources lib sources version_imports args)
    get_target_property(binary_dir ${lib} BINARY_DIR)
    # backend: cpp
    set(output_dir "${binary_dir}/gen/${lib}-cpp-source")
    set(outputs "$<PATH:REPLACE_EXTENSION,$<LIST:TRANSFORM,${sources},PREPEND,${output_dir}/>,.cpp>")
    add_custom_command(OUTPUT "${outputs}"
        COMMAND ${binary_dir}/${lib}.aidl.sh
            --lang cpp --output ${output_dir} ${args}
        DEPENDS aidl ${version_imports}
    )
    add_custom_target(${lib}-cpp-source SOURCES "${outputs}")
    target_sources(.${lib}-cpp.OBJ PRIVATE "${outputs}")
    add_dependencies(.${lib}-cpp.OBJ ${lib}-cpp-source)

    # backend: java
    set(output_dir "${binary_dir}/gen/${lib}-java-source")
    set(outputs "$<PATH:REPLACE_EXTENSION,$<LIST:TRANSFORM,${sources},PREPEND,${output_dir}/>,.java>")
    add_custom_command(OUTPUT "${outputs}"
        COMMAND ${binary_dir}/${lib}.aidl.sh
            --lang java --output ${output_dir} ${args}
        DEPENDS aidl ${version_imports}
    )
    add_custom_target(${lib}-java-source SOURCES "${outputs}")
    target_sources(.${lib}-java.SRC PRIVATE "${outputs}")
    add_dependencies(.${lib}-java.SRC ${lib}-java-source)
endfunction()


function(baker_patch_aidl_interface)
    baker_get_all_targets_recursive(all_targets ${CMAKE_SOURCE_DIR})
    foreach(target ${all_targets})
        get_property(is_aidl_patched TARGET ${target} PROPERTY _AIDL_PATCHED_)
        if(is_aidl_patched STREQUAL "FALSE")
            get_target_property(source_dir ${target} SOURCE_DIR)
            set_target_properties(${target} PROPERTIES _AIDL_PATCHED_ TRUE)
            get_target_property(src ${target} _AIDL_SRC_)
            get_target_property(version_imports ${target} _AIDL_VERSION_IMPORTS_)
            get_target_property(args ${target} _AIDL_ARGS_)

            set(rel_sources "")
            get_property(sources TARGET ${src} PROPERTY INTERFACE_SOURCES)
            get_property(local_include_dir TARGET ${src} PROPERTY _local_include_dir)
            foreach(source IN LISTS sources)
                cmake_path(RELATIVE_PATH source BASE_DIRECTORY "${source_dir}/${local_include_dir}")
                list(APPEND rel_sources "${source}")
            endforeach()
            baker_aidl_interface_patch_sources(${target} "${rel_sources}" "${version_imports}" "${args}")
        endif()
    endforeach()
endfunction()