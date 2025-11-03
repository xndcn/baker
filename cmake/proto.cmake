find_package(Protobuf)

function(baker_transform_protos sources_var)
    cmake_parse_arguments(ARGS "" "SCOPE;TARGET" "" ${ARGN})
    get_target_property(source_dir ${ARGS_TARGET} SOURCE_DIR)
    get_target_property(binary_dir ${ARGS_TARGET} BINARY_DIR)
    get_target_property(type ${ARGS_TARGET} _proto_type)
    set(sources "${${sources_var}}")
    if(type STREQUAL "nano")
        set(language "javanano")
        add_custom_command(
            OUTPUT ${binary_dir}/gen/${ARGS_TARGET}.protoc.list
            # Clean up previous build artifacts
            COMMAND ${CMAKE_COMMAND} -E rm -rf
                "${binary_dir}/gen/${ARGS_TARGET}.protoc.list"
                "${binary_dir}/gen/${ARGS_TARGET}/protoc/"
            COMMAND ${CMAKE_COMMAND} -E env PROTOC_EXECUTABLE=$<TARGET_FILE:protobuf::protoc> --
                ${CMAKE_SOURCE_DIR}/cmake/protoc.sh
                --language ${language}
                --source ${source_dir}
                --output ${binary_dir}/gen/${ARGS_TARGET}/protoc/
                --protos "${sources}"
                --plugin "protoc-gen-javanano=$<TARGET_FILE:protoc-gen-javanano>"
            COMMAND find ${binary_dir}/gen/${ARGS_TARGET}/protoc/ -type f -name "*.java" > ${binary_dir}/gen/${ARGS_TARGET}.protoc.list
            DEPENDS protoc-gen-javanano ${sources}
            VERBATIM
        )
        add_custom_target(.${ARGS_TARGET}.PROTO SOURCES "${binary_dir}/gen/${ARGS_TARGET}.protoc.list")
        if(ARGS_SCOPE STREQUAL "PRIVATE")
            set_property(TARGET ${ARGS_TARGET} APPEND PROPERTY _STUBS_SOURCES_ "@${binary_dir}/gen/${ARGS_TARGET}.protoc.list")
        else()
            set_property(TARGET ${ARGS_TARGET} APPEND PROPERTY INTERFACE__STUBS_SOURCES_ "@${binary_dir}/gen/${ARGS_TARGET}.protoc.list")
        endif()
        add_dependencies(${ARGS_TARGET} .${ARGS_TARGET}.PROTO)
        set_property(TARGET ${ARGS_TARGET} APPEND PROPERTY TRANSITIVE_COMPILE_PROPERTIES "_STUBS_SOURCES_")
    endif()
endfunction()