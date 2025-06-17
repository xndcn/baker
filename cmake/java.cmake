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
    baker_apply_sources_transform(${src})
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_libs>)
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_api_contributions>)

    add_library(${name} OBJECT ".")
    target_link_libraries(${name} PRIVATE ${src})

    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.metalava.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/metalava.template.sh" TARGET ${name})
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar" "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
        # Run metalava to generate stubs and classpath
        COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${name}.metalava.sh
            --stubs "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/"
            --classpath "$<TARGET_PROPERTY:${name},_CLASSPATH_>"
            --source-files "$<TARGET_PROPERTY:${src},INTERFACE_SOURCES>"
        COMMAND find "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/" -name "*.java" -type f > "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
        # Clean up previous build artifacts
        COMMAND ${CMAKE_COMMAND} -E rm -rf
            "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
            "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
        # Compile the Java sources and package them into a JAR
        COMMAND ${Java_JAVAC_EXECUTABLE}
            "@${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
            -source 1.8 -target 1.8
            -classpath "$<TARGET_PROPERTY:${name},_CLASSPATH_>"
            -d "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
        COMMAND ${Java_JAR_EXECUTABLE}
            cf "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
            -C "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/" .
        DEPENDS ${name} metalava
        VERBATIM
    )
    target_sources(${name} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
    set_target_properties(${name} PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
endfunction()

function(baker_java_sdk_library)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})

    # Add api_contribution, which will be used in java_api_library
    set(api_contribution "${name}.stubs.source.api.contribution")
    add_library(${api_contribution} INTERFACE)
    set(api_dir "$<IF:$<BOOL:$<TARGET_PROPERTY:${src},_api_dir>>,$<TARGET_PROPERTY:${src},_api_dir>,api>")
    target_sources(${api_contribution} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/${api_dir}/current.txt")
    # Inherit droiddoc options, flags and args from the source target
    set_target_properties(${api_contribution} PROPERTIES
        INTERFACE__droiddoc_options "$<TARGET_PROPERTY:${src},_droiddoc_options>"
        INTERFACE__flags "$<TARGET_PROPERTY:${src},_flags>"
        INTERFACE__args "$<TARGET_PROPERTY:${src},_args>"
    )
    set_target_properties(${api_contribution} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_droiddoc_options" "_flags" "_args")
endfunction()

function(baker_java_system_modules)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_libs>)

    add_library(${name} OBJECT ".")
    target_link_libraries(${name} PRIVATE ${src})
    set(outputs
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/modules/module.jar"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/modules/module-info.class"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/modules/jmod/java.base.jmod"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/system/lib/jrt-fs.jar"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/system/lib/modules"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/system/release"
    )
    add_custom_command(
        OUTPUT ${outputs}
        COMMAND ${CMAKE_COMMAND} -E env
            Java_JAVAC_EXECUTABLE=${Java_JAVAC_EXECUTABLE}
            Java_JAR_EXECUTABLE=${Java_JAR_EXECUTABLE}
            ZIPMERGE=${CMAKE_SOURCE_DIR}/cmake/zipmerge.py
            --
        ${CMAKE_SOURCE_DIR}/cmake/java_system_modules.sh
            --jars "$<TARGET_PROPERTY:${name},_CLASSPATH_>"
            --outDir "${CMAKE_CURRENT_BINARY_DIR}/${name}/"
            --moduleVersion "${Java_VERSION_STRING}"
        DEPENDS ${name}
        VERBATIM
    )
    target_sources(${name} PRIVATE ${outputs})
    set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
    set_target_properties(${name} PROPERTIES INTERFACE__SYSTEM_MODULES_PATH_ "${CMAKE_CURRENT_BINARY_DIR}/${name}/system/")
    # For java_system_modules(a) -> java_library(b) -> java_system_modules(c)
    # If we use TRANSITIVE_LINK_PROPERTIES, then c will also inherit _SYSTEM_MODULES_PATH_ from a
    # But we only want the _SYSTEM_MODULES_PATH_ from c itself
    # So we have to use TRANSITIVE_COMPILE_PROPERTIES instead
    set_target_properties(${name} PROPERTIES TRANSITIVE_COMPILE_PROPERTIES "_SYSTEM_MODULES_PATH_")
endfunction()

function(baker_java_library)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_libs>)
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_static_libs>)
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_system_modules>)

    add_library(${name} OBJECT ".")
    target_link_libraries(${name} PRIVATE ${src})

    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.java_library.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/java_library.template.sh" TARGET ${src})
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
        # Clean up previous build artifacts
        COMMAND ${CMAKE_COMMAND} -E rm -rf
            "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
            "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
        # Compile the Java sources and package them into a JAR
        COMMAND ${CMAKE_COMMAND} -E env Java_JAVAC_EXECUTABLE=${Java_JAVAC_EXECUTABLE}
            ${CMAKE_CURRENT_BINARY_DIR}/${name}.java_library.sh
            -d "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
        COMMAND ${Java_JAR_EXECUTABLE}
            cf "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
            -C "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/" .
        DEPENDS ${name} ${CMAKE_CURRENT_BINARY_DIR}/${name}.java_library.sh
        VERBATIM
    )

    target_sources(${name} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
    set_target_properties(${name} PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
endfunction()