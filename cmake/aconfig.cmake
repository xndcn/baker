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
    baker_parse_properties(${src})

    add_library(${name} OBJECT ".")
    set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)

    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.pb"
        COMMAND cmake -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/gen/"
        COMMAND aconfig ARGS create-cache
            --package "$<TARGET_PROPERTY:${src},_package>"
            --container "$<TARGET_PROPERTY:${src},_container>"
            --cache "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.pb"
            --declarations "$<TARGET_PROPERTY:${src},INTERFACE_SOURCES>"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS $<TARGET_PROPERTY:${src},INTERFACE_SOURCES>
        VERBATIM
    )
    add_custom_target(.${name}.DEP SOURCES "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.pb")
    target_sources(${name} INTERFACE "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.pb")
    add_dependencies(${name} .${name}.DEP)
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
