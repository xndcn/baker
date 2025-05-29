find_package(Java REQUIRED COMPONENTS Development)
if(Java_FOUND)
    message(STATUS "Java ${Java_VERSION} found: ${Java_JAVAC_EXECUTABLE}")
endif()

if(EXISTS "${CMAKE_SOURCE_DIR}/tools/metalava")
    # Build metalava
    include(ExternalProject)
    ExternalProject_Add(metalava_build
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/tools/metalava
        BUILD_IN_SOURCE TRUE
        # Disable JAVA_HOME export in gradlew
        CONFIGURE_COMMAND sed -i "s/^export JAVA_HOME=/#export JAVA_HOME=/" ${CMAKE_SOURCE_DIR}/tools/metalava/gradlew
        BUILD_COMMAND OUT_DIR=${CMAKE_BINARY_DIR}/ ./gradlew installDist
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS "${CMAKE_BINARY_DIR}/metalava/metalava/build/install/metalava/bin/metalava"
    )
    # Import the built binary
    add_executable(metalava IMPORTED GLOBAL)
    add_dependencies(metalava metalava_build)
    set_target_properties(metalava PROPERTIES IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/metalava/metalava/build/install/metalava/bin/metalava)
endif()


function(baker_java_api_library)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_libs>)
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_api_contributions>)

    baker_target_list_property(droiddoc_options TARGETS $<TARGET_PROPERTY:${src},_api_contributions> PROPERTY _droiddoc_options)
    baker_target_list_property(flags TARGETS $<TARGET_PROPERTY:${src},_api_contributions> PROPERTY _flags)
    baker_target_list_property(args TARGETS $<TARGET_PROPERTY:${src},_api_contributions> PROPERTY _args)
    set_target_properties(${src} PROPERTIES 
        _droiddoc_options ${droiddoc_options}
        _flags ${flags}
        _args ${args}
    )

    set(dep ${src} $<TARGET_PROPERTY:${src},_libs> $<TARGET_PROPERTY:${src},_api_contributions>)

    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.metalava.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/metalava.template.sh" TARGET ${src})
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
        COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${name}.metalava.sh
            --stubs "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/"
            --classpath "$<TARGET_PROPERTY:${src},INTERFACE__CLASSPATH_>"
            --source-files "$<TARGET_PROPERTY:${src},INTERFACE_SOURCES>"
        COMMAND find "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/" -name "*.java" -type f > "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
        DEPENDS ${dep} metalava
        VERBATIM
    )
    add_custom_target(${name}-metalava SOURCES "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list")

    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
        COMMAND ${CMAKE_COMMAND} -E rm -rf 
            "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
            "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
        COMMAND ${Java_JAVAC_EXECUTABLE}
            "@${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
            -source 1.8 -target 1.8
            -classpath "$<TARGET_PROPERTY:${src},INTERFACE__CLASSPATH_>"
            -d "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
        COMMAND ${Java_JAR_EXECUTABLE}
            cf "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
            -C "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/" .
        DEPENDS ${dep} ${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list
        VERBATIM
    )
    add_library(${name} OBJECT ".")
    set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
    set_target_properties(${name} PROPERTIES OBJECT_DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
endfunction()

function(baker_java_sdk_library)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})

    # Add api_contribution, which will be used in java_api_library
    set(api_contribution "${name}.stubs.source.api.contribution")
    add_library(${api_contribution} INTERFACE)
    set(api_dir "$<IF:$<BOOL:$<TARGET_PROPERTY:${src},_api_dir>>,$<TARGET_PROPERTY:${src},_api_dir>,api>")
    target_sources(${api_contribution} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/${api_dir}/current.txt")
    # Inherit droiddoc options, flags and args from the source target
    set_target_properties(${api_contribution} PROPERTIES
        _droiddoc_options "$<TARGET_PROPERTY:${src},_droiddoc_options>"
        _flags "$<TARGET_PROPERTY:${src},_flags>"
        _args "$<TARGET_PROPERTY:${src},_args>"
    )
endfunction()