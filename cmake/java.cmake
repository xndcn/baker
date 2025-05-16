find_package(Java REQUIRED COMPONENTS Development)
if(Java_FOUND)
    message(STATUS "Java ${Java_VERSION} found: ${Java_JAVAC_EXECUTABLE}")
endif()

# Import the built binary
add_executable(metalava IMPORTED GLOBAL)
set_target_properties(metalava PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/out/metalava/metalava/build/install/metalava/bin/metalava)
add_executable(turbine IMPORTED GLOBAL)
set_target_properties(turbine PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/utils/turbine)

# Internal target for storing all java_library targets
add_library(.BAKER_JAVA.LIBS INTERFACE)
set_target_properties(.BAKER_JAVA.LIBS PROPERTIES _libs "")
set_target_properties(.BAKER_JAVA.LIBS PROPERTIES _sdk_libs "")

# api scopes
set(API_SCOPES "public" ; "system" ; "module_lib")
set(API_SCOPES_ENABLED_DEFAULT ON; OFF; OFF)
set(API_SCOPES_SUFFIX "" ; ".system" ; ".module_lib")

function(baker_add_java_library target)
    set_property(TARGET .BAKER_JAVA.LIBS APPEND PROPERTY _libs "${target}")
endfunction()

function(baker_add_java_sdk_library target)
    set_property(TARGET .BAKER_JAVA.LIBS APPEND PROPERTY _sdk_libs "${target}")
endfunction()

function(baker_get_java_package java_file out_var)
    set(${out_var} "")
    file(STRINGS "${java_file}" contents)
    foreach(line IN LISTS contents)
        string(REGEX MATCH "^package[ \t]+(.+);$" match "${line}")
        if(match)
            set(${out_var} "${CMAKE_MATCH_1}" PARENT_SCOPE)
            break()
        endif()
    endforeach()
endfunction()

function(baker_add_java_library_impl lib)
    get_property(defaults_list TARGET ${lib} PROPERTY _defaults)
    if(defaults_list)
        baker_inherit_defaults(${lib} ${defaults_list})
    endif(defaults_list)

    get_property(source_dir TARGET ${lib} PROPERTY SOURCE_DIR)
    get_property(output_dir TARGET ${lib} PROPERTY BINARY_DIR)
    file(GENERATE OUTPUT "${output_dir}/${lib}.src" CONTENT "$<JOIN:$<LIST:FILTER,$<TARGET_PROPERTY:${lib},INTERFACE_SOURCES>,EXCLUDE,^@>,\n>")
    get_property(keys TARGET ${lib} PROPERTY _ALL_SINGLE_KEYS_)
    set(flags "")
    if("_patch_module" IN_LIST keys)
        get_property(module TARGET ${lib} PROPERTY _patch_module)
        list(APPEND flags --patch-module ${module}=${source_dir})
    endif()
    # Execute javac with the generated java.src file as arguments
    add_custom_command(
        OUTPUT "${output_dir}/${lib}.jar"
        COMMAND ${Java_JAVAC_EXECUTABLE}
            "@${output_dir}/${lib}.src"
            "$<LIST:FILTER,$<TARGET_PROPERTY:${lib},INTERFACE_SOURCES>,INCLUDE,^@>"
            -d "${output_dir}/${lib}/"
            "${flags}"
        DEPENDS "${output_dir}/${lib}.src" ; $<LIST:TRANSFORM,$<TARGET_PROPERTY:${lib},INTERFACE_SOURCES>,REPLACE,^@,>
        VERBATIM COMMAND_EXPAND_LISTS
    )
    add_custom_target(${lib}-jar SOURCES "${output_dir}/${lib}.jar" DEPENDS ${lib})
endfunction()

function(baker_get_java_sources_info srcs out_sources out_package_roots)
    set(out_srcs "")
    set(package_root_list "")
    foreach(source_file IN LISTS srcs)
        # Get the directory of the source file
        get_filename_component(source_dir "${source_file}" DIRECTORY)
        get_filename_component(source_name "${source_file}" NAME)

        # Check if the source file is in a subdirectory of any package path
        set(is_in_package FALSE)
        foreach(package_root_path IN ZIP_LISTS package_root_list)
            if("${source_dir}" MATCHES "^${package_root_path}")
                set(is_in_package TRUE)
                break()
            endif()
        endforeach()

        if(NOT is_in_package)
            baker_get_java_package(${source_file} package)
            if(package STREQUAL "")
                message(WARNING "No package name found in ${source_file}")
            endif()
            # Convert package name from dots to slashes (foo.bar -> foo/bar)
            string(REPLACE "." "/" package_path "${package}")
            # Find the package root by removing the package path from the source directory
            string(REPLACE "${package_path}" "" package_root_path "${source_dir}")
            list(APPEND package_root_list "${package_root_path}")
        endif()

        # Extract the relative path from the package root path using cmake_path
        cmake_path(RELATIVE_PATH source_dir BASE_DIRECTORY "${package_root_path}" OUTPUT_VARIABLE rel_path)
        list(APPEND out_srcs "${rel_path}/${source_name}")
    endforeach()

    set(${out_sources} "${out_srcs}" PARENT_SCOPE)
    set(${out_package_roots} "${package_root_list}" PARENT_SCOPE)
endfunction()

function(baker_add_java_sdk_library_impl lib)
    get_property(defaults_list TARGET ${lib} PROPERTY _defaults)
    if(defaults_list)
        baker_inherit_defaults(${lib} ${defaults_list})
    endif(defaults_list)
    foreach(scope enabled_default suffix IN ZIP_LISTS API_SCOPES API_SCOPES_ENABLED_DEFAULT API_SCOPES_SUFFIX)
        get_target_property(enabled ${lib} _${scope}_enabled)
        if(enabled STREQUAL "enabled-NOTFOUND")
            set(enabled ${enabled_default})
        endif()
        set(stub_name "${lib}.stubs${suffix}")
        if(enabled)
        endif()
    endforeach()

    # Generate java.src file with all source file paths of the target
    get_property(output_dir TARGET ${lib} PROPERTY BINARY_DIR)
    file(GENERATE OUTPUT "${output_dir}/${lib}.src" CONTENT "$<JOIN:$<TARGET_PROPERTY:${lib},INTERFACE_SOURCES>,\n>")
    file(GENERATE OUTPUT "${output_dir}/${lib}.metalava.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/metalava.template.sh" TARGET ${lib} USE_SOURCE_PERMISSIONS)

    set(merged_annotations_dirs "")
    get_target_property(annotations_dirs ${lib} _merge_inclusion_annotations_dirs)
    if(NOT annotations_dirs STREQUAL "annotations_dirs-NOTFOUND")
        foreach(dirs IN LISTS annotations_dirs)
            list(APPEND merged_annotations_dirs "$<TARGET_PROPERTY:${dirs},INTERFACE_INCLUDE_DIRECTORIES>")
        endforeach()
    endif()
    get_target_property(system_modules ${lib} _system_modules)

    set(classpath "")
    if(NOT system_modules STREQUAL "system_modules-NOTFOUND" AND NOT system_modules STREQUAL "none")
        list(APPEND classpath "$<TARGET_PROPERTY:${system_modules},INTERFACE_SOURCES>")
    endif()

    # Execute metalava with the generated java.src file as arguments
    add_custom_command(
        OUTPUT "${output_dir}/${lib}.metalava.list"
        COMMAND ${output_dir}/${lib}.metalava.sh
            --stubs "${output_dir}/${lib}/stubs/"
            --merge-inclusion-annotations "$<JOIN:${merged_annotations_dirs},:>"
            --classpath "${classpath}"
            --src "${output_dir}/${lib}.src" || echo
        COMMAND find "${output_dir}/${lib}/stubs/" -name "*.java" -type f > "${output_dir}/${lib}.metalava.list"
        DEPENDS $<TARGET_PROPERTY:${lib},INTERFACE_SOURCES> ; ${lib} ; "${output_dir}/${lib}.src" 
        VERBATIM
    )
    add_custom_target(${lib}-metalava SOURCES "${output_dir}/${lib}.metalava.list")
    add_library(${lib}_.public.stubs.source_ INTERFACE)
    set_target_properties(${lib}_.public.stubs.source_ PROPERTIES INTERFACE_SOURCES "@${output_dir}/${lib}.metalava.list")
    add_dependencies(${lib}_.public.stubs.source_ ${lib}-metalava)

    add_custom_command(
        OUTPUT "${output_dir}/${lib}.turbine.jar"
        COMMAND turbine
            --sources "@${output_dir}/${lib}.metalava.list"
            --output "${output_dir}/${lib}.turbine.jar"
        DEPENDS ${output_dir}/${lib}.metalava.list
    )
    add_custom_target(${lib}-turbine SOURCES "${output_dir}/${lib}.turbine.jar")
    add_library(${lib}.stubs INTERFACE)
    target_sources(${lib}.stubs INTERFACE "${output_dir}/${lib}.turbine.jar")
endfunction()

function(baker_patch_java_library)
    get_property(libs TARGET .BAKER_JAVA.LIBS PROPERTY _libs)
    foreach(lib IN LISTS libs)
        baker_add_java_library_impl(${lib})
    endforeach()
    get_property(libs TARGET .BAKER_JAVA.LIBS PROPERTY _sdk_libs)
    foreach(lib IN LISTS libs)
        baker_add_java_sdk_library_impl(${lib})
    endforeach()
endfunction()