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

    set_property(TARGET ${target} PROPERTY SOURCES ${new_private_sources})
    set_property(TARGET ${target} PROPERTY INTERFACE_SOURCES ${new_interface_sources})
endfunction(baker_apply_sources_transform)

# Function to create an AIDL library
function(add_aidl_library target)
    cmake_parse_arguments(AIDL "" "API_DIR;VERSION" "SRCS;DEPS;FLAGS" ${ARGN})
    
    # Create the interface library
    add_library(${target} INTERFACE)
    
    # Store paths for inclusion in dependent targets
    set_target_properties(${target} PROPERTIES
        _is_aidl_library TRUE
        _aidl_flags "${AIDL_FLAGS}"
        _path "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    
    if(AIDL_SRCS)
        # Process source files
        set_property(TARGET ${target} PROPERTY INTERFACE_SOURCES ${AIDL_SRCS})
        baker_apply_sources_transform(${target})
    elseif(AIDL_API_DIR)
        # Store API directory for generation
        set_target_properties(${target} PROPERTIES 
            _aidl_api_dir "${AIDL_API_DIR}"
        )
    endif()
    
    if(AIDL_VERSION)
        set_target_properties(${target} PROPERTIES
            _aidl_version "${AIDL_VERSION}"
        )
    endif()
    
    # Process dependencies
    if(AIDL_DEPS)
        target_link_libraries(${target} INTERFACE ${AIDL_DEPS})
    endif()
endfunction()

# Functions to create language-specific AIDL implementations
function(add_aidl_cpp_library target)
    cmake_parse_arguments(AIDL "" "MIN_SDK_VERSION" "DEPS;SHARED_LIBS;CPPFLAGS" ${ARGN})
    
    add_library(${target} SHARED)
    
    # Link to the base AIDL interface library
    if(AIDL_DEPS)
        foreach(dep ${AIDL_DEPS})
            # Apply properties from the AIDL interface
            get_target_property(is_aidl_lib ${dep} _is_aidl_library)
            if(is_aidl_lib)
                target_link_libraries(${target} PRIVATE ${dep})
                # Include any other needed setup for cpp implementation
            endif()
        endforeach()
    endif()
    
    # Process shared library dependencies
    if(AIDL_SHARED_LIBS)
        target_link_libraries(${target} PRIVATE ${AIDL_SHARED_LIBS})
    endif()
    
    # Apply any C++ flags
    if(AIDL_CPPFLAGS)
        target_compile_options(${target} PRIVATE ${AIDL_CPPFLAGS})
    endif()
    
    if(AIDL_MIN_SDK_VERSION)
        set_target_properties(${target} PROPERTIES
            _min_sdk_version "${AIDL_MIN_SDK_VERSION}"
        )
    endif()
endfunction()

function(add_aidl_ndk_library target)
    # Same pattern as add_aidl_cpp_library with NDK-specific handling
    add_aidl_cpp_library(${target} ${ARGN})
    set_target_properties(${target} PROPERTIES _aidl_backend "ndk")
endfunction()

function(add_aidl_java_library target)
    cmake_parse_arguments(AIDL "" "MIN_SDK_VERSION" "DEPS" ${ARGN})
    
    add_library(${target} INTERFACE)
    
    # Link to the base AIDL interface library
    if(AIDL_DEPS)
        target_link_libraries(${target} INTERFACE ${AIDL_DEPS})
    endif()
    
    if(AIDL_MIN_SDK_VERSION)
        set_target_properties(${target} PROPERTIES
            _min_sdk_version "${AIDL_MIN_SDK_VERSION}"
        )
    endif()
    
    set_target_properties(${target} PROPERTIES _aidl_backend "java")
endfunction()