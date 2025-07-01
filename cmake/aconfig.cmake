# Check if the aconfig source directory exists
if(EXISTS "${CMAKE_SOURCE_DIR}/build/tools/aconfig/aconfig")
    # Hack for finalized_flags_record.json, which should be generated using prebuilts/sdk
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/prebuilts/sdk/0")
    file(WRITE "${CMAKE_SOURCE_DIR}/prebuilts/sdk/0/finalized-flags.txt" "")
    # Build aconfig Rust cargo project
    include(ExternalProject)
    ExternalProject_Add(aconfig_rust
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/build/tools/aconfig/aconfig
        BUILD_IN_SOURCE TRUE
        CONFIGURE_COMMAND ""
        BUILD_COMMAND cargo build --release --target-dir ${CMAKE_BINARY_DIR}/aconfig_build
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${CMAKE_BINARY_DIR}/aconfig_build/release/aconfig
    )

    # Import the built binary
    add_executable(aconfig IMPORTED GLOBAL)
    add_dependencies(aconfig aconfig_rust)
    set_target_properties(aconfig PROPERTIES IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/aconfig_build/release/aconfig)
endif()


function(baker_aconfig_declarations)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})

    add_library(${name} OBJECT "${BAKER_DUMMY_C_SOURCE}")
    baker_parse_properties(${name})

    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.pb"
        COMMAND cmake -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/gen/"
        COMMAND aconfig ARGS create-cache
            --package "$<TARGET_PROPERTY:${name},_package>"
            --container "$<TARGET_PROPERTY:${name},_container>"
            --cache "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.pb"
            --declarations "$<TARGET_PROPERTY:${src},INTERFACE_SOURCES>"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS $<TARGET_PROPERTY:${src},INTERFACE_SOURCES>
        VERBATIM
    )

    # Since .pb file can not been built into object, we can safely use it as source
    target_sources(${name} PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.pb")
endfunction()

function(baker_cc_aconfig_library)
    baker_parse_metadata(${ARGN})

    add_library(${name}-static STATIC)
    baker_parse_properties(${name}-static)

    # add_custom_command OUTPUT can not contains generator expressions with target property
    # so use get_property here
    get_property(package TARGET ${ARG_aconfig_declarations} PROPERTY _package)
    set(package $<LIST:TRANSFORM,${package},REPLACE,[.],_>)
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/${package}.cc" "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/include/${package}.h"
        COMMAND aconfig ARGS create-cpp-lib
            --cache "$<TARGET_PROPERTY:$<TARGET_PROPERTY:${name}-static,_aconfig_declarations>,INTERFACE_SOURCES>"
            --out "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS $<TARGET_PROPERTY:${name}-static,_aconfig_declarations>
        VERBATIM
    )

    target_sources(${name}-static PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/${package}.cc")
    target_include_directories(${name}-static PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/include")
endfunction()

function(baker_java_aconfig_library)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_system_modules>)

    get_target_property(package ${ARG_aconfig_declarations} _package)
    set(package $<LIST:TRANSFORM,${package},REPLACE,[.],/>)
    set(outputs
        "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/${package}/Flags.java"
        "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/${package}/CustomFeatureFlags.java"
        "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/${package}/FakeFeatureFlagsImpl.java"
        "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/${package}/FeatureFlagsImpl.java"
        "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/${package}/FeatureFlags.java"
    )

    add_custom_command(
        OUTPUT ${outputs}
        COMMAND aconfig ARGS create-java-lib
            --cache "$<TARGET_PROPERTY:$<TARGET_PROPERTY:${src},_aconfig_declarations>,INTERFACE_SOURCES>"
            --out "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS $<TARGET_PROPERTY:${src},_aconfig_declarations>
        VERBATIM
    )
    target_sources(${src} INTERFACE "${outputs}")
    set_target_properties(${src} PROPERTIES _SOURCE_DIR_ "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/")

    add_library(${name} OBJECT "${BAKER_DUMMY_C_SOURCE}")
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
        DEPENDS ${name} ${outputs} ${CMAKE_CURRENT_BINARY_DIR}/${name}.java_library.sh
        VERBATIM
    )

    target_sources(${name} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
endfunction()