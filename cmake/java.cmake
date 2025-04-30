find_package(Java REQUIRED COMPONENTS Development)
if(Java_FOUND)
    message(STATUS "Java ${Java_VERSION} found: ${Java_JAVAC_EXECUTABLE}")
endif()
include(UseJava)

# Internal target for storing all java_library targets
add_library(.BAKER_JAVA.LIBS INTERFACE)
set_target_properties(.BAKER_JAVA.LIBS PROPERTIES _libs "")

function(baker_add_java_library target)
    set_property(TARGET .BAKER_JAVA.LIBS APPEND PROPERTY _libs "${target}")
endfunction()

function(baker_patch_java_library)
    get_property(libs TARGET .BAKER_JAVA.LIBS PROPERTY _libs)
    foreach(lib IN LISTS libs)
        get_property(defaults_list TARGET ${lib} PROPERTY _defaults)
        if(defaults_list)
            baker_inherit_defaults(${lib} ${defaults_list})
        endif(defaults_list)
        baker_get_sources(srcs ${lib} SCOPE INTERFACE)
        get_property(output_dir TARGET ${lib} PROPERTY BINARY_DIR)
        get_property(source_dir TARGET ${lib} PROPERTY SOURCE_DIR)
        get_property(keys TARGET ${lib} PROPERTY _ALL_SINGLE_KEYS_)
        set(CMAKE_JAVA_COMPILE_FLAGS "")
        if("_patch_module" IN_LIST keys)
            get_property(module TARGET ${lib} PROPERTY _patch_module)
            list(APPEND CMAKE_JAVA_COMPILE_FLAGS --patch-module ${module}=${source_dir})
        endif()
        add_jar(${lib}-jar 
            SOURCES ${srcs}
            OUTPUT_DIR ${output_dir}
        )
    endforeach()
endfunction()