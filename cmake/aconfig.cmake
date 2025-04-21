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