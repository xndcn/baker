function(baker_hidl_is_core_package out_var name)
    # See system/tools/hidl/build/hidl_interface.go:isCorePackage
    set(coreDependencyPackageNames "android.hidl.base@;android.hidl.manager@")
    foreach(core_name IN LISTS coreDependencyPackageNames)
        if(name MATCHES "^${core_name}")
            set(${out_var} TRUE PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${out_var} FALSE PARENT_SCOPE)
endfunction()

function(baker_hidl_sanitized_name out_var name)
    # See system/tools/hidl/build/fqName.go:sanitizedString
    # Sanitize name from foo.bar@1.0 to foo.bar-V1.0
    string(REGEX MATCH "([^@]+)@(.+)" _ "${name}")
    set(${out_var} "${CMAKE_MATCH_1}-V${CMAKE_MATCH_2}" PARENT_SCOPE)
endfunction()

function(baker_hidl_interface)
    baker_parse_metadata(${ARGN})
    # Get origin name without canonicalization
    set(hidl_name "${ARG_name}")

    set(PROP ".${name}.PROP")
    add_library(${PROP} INTERFACE)
    baker_parse_properties(${PROP})

    # Convert name from foo.bar@1.0 to foo/bar/1.0
    string(REGEX MATCH "([^@]+)@(.+)" _ "${hidl_name}")
    string(REPLACE "." "/" package "${CMAKE_MATCH_1}")
    set(dir "${package}/${CMAKE_MATCH_2}")
    # Convert name from foo.bar@1.0 to foo/bar/V1_0
    string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)$" "V\\1_\\2" sanitized_version "${CMAKE_MATCH_2}")
    set(sanitized_dir "${package}/${sanitized_version}")

    # TODO: support srcs in defaults
    # add_custom_command OUTPUT can not contains generator expressions with target property
    set(output_cpp_dir "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/sources/")
    set(output_h_dir "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/include/")
    set(output_cpp_files "")
    set(output_h_files "")
    foreach(source IN LISTS ARG_srcs)
        # If source contains leading upper letter 'I'
        if(source MATCHES "^I.+\\.hal$")
            get_filename_component(filename "${source}" NAME_WE)
            # remove leading 'I' and add All suffix
            string(SUBSTRING "${filename}" 1 -1 filename)
            set(source "${filename}All.hal")
        endif()
        cmake_path(ABSOLUTE_PATH source BASE_DIRECTORY "${output_cpp_dir}/${dir}" OUTPUT_VARIABLE cpp_source)
        cmake_path(REPLACE_EXTENSION cpp_source "cpp")
        list(APPEND output_cpp_files "${cpp_source}")
        cmake_path(ABSOLUTE_PATH source BASE_DIRECTORY "${output_h_dir}/${dir}" OUTPUT_VARIABLE h_source)
        cmake_path(REPLACE_EXTENSION h_source "h")
        list(APPEND output_h_files "${h_source}")
    endforeach()

    # TODO: support interfaces in defaults
    set(cpp_dependencies "")
    set(java_dependencies "")
    foreach(interface IN LISTS ARG_interfaces)
        baker_hidl_is_core_package(is_core "${interface}")
        if(NOT is_core)
            baker_canonicalize_name(cpp_name "${interface}")
            list(APPEND cpp_dependencies "${cpp_name}")
        endif()
        baker_hidl_sanitized_name(sanitized_name "${interface}")
        list(APPEND java_dependencies "${sanitized_name}-java")
    endforeach()

    # cpp-sources
    add_custom_command(
        OUTPUT ${output_cpp_files}
        # TODO: pass -R and -r options
        DEPENDS ${ARG_srcs}
        COMMAND hidl-gen -p . -o ${output_cpp_dir} -L c++-sources ${hidl_name}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        DEPENDS ${ARG_srcs}
    )
    add_custom_target(.${name}.GEN.CPP SOURCES ${output_cpp_files})
    add_library(${name}_genc++ OBJECT "${BAKER_DUMMY_C_SOURCE}")
    target_sources(${name}_genc++ INTERFACE ${output_cpp_files})
    add_dependencies(${name}_genc++ .${name}.GEN.CPP)
    # cpp-headers
    add_custom_command(
        OUTPUT ${output_h_files}
        DEPENDS ${ARG_srcs}
        COMMAND hidl-gen -p . -o ${output_h_dir} -L c++-headers ${hidl_name}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        DEPENDS ${ARG_srcs}
    )
    add_custom_target(.${name}.GEN.H SOURCES ${output_h_files})
    add_library(${name}_genc++_headers OBJECT "${BAKER_DUMMY_C_SOURCE}")
    target_sources(${name}_genc++_headers INTERFACE ${output_h_files})
    target_include_directories(${name}_genc++_headers INTERFACE ${output_h_dir})
    add_dependencies(${name}_genc++_headers .${name}.GEN.H)
    # cpp library
    baker_cc_library(
        name "${name}"
        # See system/tools/hidl/build/hidl_interface.go:hidlInterfaceMutator
        shared_libs "libhidlbase;liblog;libutils;libcutils;${cpp_dependencies}"
        export_shared_libs "libhidlbase;libutils;${cpp_dependencies}"
        _ALL_LIST_KEYS_ "shared_libs;export_shared_libs"
        _ALL_SINGLE_KEYS_ ""
    )
    target_link_libraries(.${name}.OBJ PRIVATE ${name}_genc++ ${name}_genc++_headers)

    # TODO: check if gen_java is set
    baker_hidl_sanitized_name(sanitized_name "${hidl_name}")
    # java-sources
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.java.list"
        COMMAND hidl-gen -p . -o ${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/java/ -L java ${hidl_name}
        COMMAND find ${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/java/ -name "*.java" > "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.java.list"
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )
    add_custom_target(.${name}.GEN.JAVA SOURCES "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.java.list")
    add_library(${sanitized_name}-java_gen_java OBJECT "${BAKER_DUMMY_C_SOURCE}" "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.java.list")
    set_property(TARGET ${sanitized_name}-java_gen_java PROPERTY INTERFACE__STUBS_SOURCES_ "@${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.java.list")
    set_property(TARGET ${sanitized_name}-java_gen_java PROPERTY TRANSITIVE_COMPILE_PROPERTIES "_STUBS_SOURCES_")
    add_dependencies(${sanitized_name}-java_gen_java .${name}.GEN.JAVA)
    # java library
    baker_java_library(
        name "${sanitized_name}-java"
        # See system/tools/hidl/build/hidl_interface.go:hidlInterfaceMutator
        libs "hwbinder.stubs"
        static_libs "${java_dependencies}"
        sdk_version "core_current"
        is_stubs_module TRUE
        _ALL_LIST_KEYS_ "libs;static_libs"
        _ALL_SINGLE_KEYS_ "sdk_version;is_stubs_module"
    )
    target_link_libraries(.${sanitized_name}-java.SRC PRIVATE ${sanitized_name}-java_gen_java)

    # TODO: check if gen_java_constants is set
    # java-constants-sources
    set(outputs "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/java-constants/${sanitized_dir}/Constants.java")
    add_custom_command(
        OUTPUT "${outputs}"
        COMMAND hidl-gen -p . -o ${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/java-constants/ -L java-constants ${hidl_name}
        DEPENDS ${hidl_name}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )
    add_custom_target(.${name}.GEN.JAVA_CONSTANTS SOURCES "${outputs}")
    add_library(${sanitized_name}-java-constants_gen_java OBJECT "${BAKER_DUMMY_C_SOURCE}" "${outputs}")
    target_sources(${sanitized_name}-java-constants_gen_java INTERFACE "${outputs}")
    add_dependencies(${sanitized_name}-java-constants_gen_java .${name}.GEN.JAVA_CONSTANTS)
    # java-constants library
    baker_java_library(
        name "${sanitized_name}-java-constants"
        srcs ":${sanitized_name}-java-constants_gen_java"
        sdk_version "core_current"
        is_stubs_module TRUE
        _ALL_LIST_KEYS_ "srcs"
        _ALL_SINGLE_KEYS_ "sdk_version;is_stubs_module"
    )
endfunction()