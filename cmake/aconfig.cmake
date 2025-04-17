# Check if the aconfig source directory exists
if(EXISTS "${CMAKE_SOURCE_DIR}/build/tools/aconfig/aconfig")
    # Build aconfig Rust cargo project
    include(ExternalProject)
    ExternalProject_Add(aconfig_rust
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/build/tools/aconfig/aconfig
        BUILD_IN_SOURCE TRUE
        # hack for finalized_flags_record.json, which should be generated using prebuilts/sdk
        PATCH_COMMAND mkdir -p ${CMAKE_BINARY_DIR}/aconfig_build/release/build/aconfig-838d47a1bd6e8134/out/
        CONFIGURE_COMMAND touch ${CMAKE_BINARY_DIR}/aconfig_build/release/build/aconfig-838d47a1bd6e8134/out/finalized_flags_record.json
        BUILD_COMMAND cargo build --release --target-dir ${CMAKE_BINARY_DIR}/aconfig_build
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${CMAKE_BINARY_DIR}/aconfig_build/release/aconfig
    )

    # Import the built binary
    add_executable(aconfig IMPORTED GLOBAL)
    add_dependencies(aconfig aconfig_rust)
    set_target_properties(aconfig PROPERTIES IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/aconfig_build/release/aconfig)
endif()