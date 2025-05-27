function(baker_cc_apply_properties target dependency)
    # Process include directories
    set(include_dirs "")
    set(export_include_dirs "")
    list(APPEND include_dirs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_local_include_dirs>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
    foreach(dir "include_dirs")
        list(APPEND include_dirs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_${dir}>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
        list(APPEND export_include_dirs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_${dir}>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
    endforeach()
    set(link_libs "")
    set(export_link_libs "")
    # Process header libraries
    foreach(lib "header_libs" ; "header_lib_headers")
        list(APPEND link_libs $<TARGET_PROPERTY:${dependency},_${lib}>)
        list(APPEND export_link_libs $<TARGET_PROPERTY:${dependency},_export_${lib}>)
    endforeach()
    # Process generated sources
    list(APPEND link_libs $<TARGET_PROPERTY:${dependency},_generated_sources>)
    # Process generated headers
    list(APPEND link_libs $<TARGET_PROPERTY:${dependency},_generated_headers>)
    # Process shared libraries
    foreach(lib "shared_libs" ; "shared_lib_headers" ; "shared_shared_libs") # shared_shared_libs for {"shared": {"shared_libs": [...]}}
        # CMake will export private linked shared libraries for static, but not for shared
        # so export all shared libraries by default
        list(APPEND export_link_libs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_${lib}>,APPEND,-shared>)
        list(APPEND export_link_libs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_${lib}>,APPEND,-shared>)
    endforeach()
    # Process static libraries
    foreach(lib "static_libs" ; "static_lib_headers")
        list(APPEND link_libs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_${lib}>,APPEND,-static>)
        list(APPEND export_link_libs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_${lib}>,APPEND,-static>)
    endforeach()
    # Process whole_static_libs
    list(APPEND link_libs $<LINK_LIBRARY:WHOLE_ARCHIVE,$<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_whole_static_libs>,APPEND,-static>>)
    list(APPEND export_link_libs $<LINK_LIBRARY:WHOLE_ARCHIVE,$<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_whole_static_libs>,APPEND,-static>>)
    set(link_libs "$<LIST:TRANSFORM,${link_libs},REPLACE,#impl,+impl>")
    set(export_link_libs "$<LIST:TRANSFORM,${export_link_libs},REPLACE,#impl,+impl>")
    # Combo libraries and include directories
    target_include_directories(${target} PRIVATE ${include_dirs})
    target_include_directories(${target} PUBLIC ${export_include_dirs})
    target_link_libraries(${target} PRIVATE ${link_libs})
    target_link_libraries(${target} PUBLIC ${export_link_libs})
    # double __ prefix to avoid collision with other properties
    set_property(TARGET ${target} APPEND PROPERTY __export_dirs ${export_include_dirs})
    set_property(TARGET ${target} APPEND PROPERTY __export_libs ${export_link_libs})
    # Process cflags
    target_compile_options(${target} PRIVATE $<TARGET_PROPERTY:${dependency},_cflags>)
    # Linker flags
    target_link_options(${target} PRIVATE $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_linker_script>,PREPEND,-T${CMAKE_CURRENT_SOURCE_DIR}/>)
    target_link_options(${target} PRIVATE $<TARGET_PROPERTY:${dependency},_ldflags>)
endfunction()

function(baker_cc_binary)
    baker_parse_metadata(${ARGN})
    add_executable(${name})
    baker_parse_properties(${name})
    target_sources(${name} PRIVATE ${ARG_srcs})

    # hack for no srcs
    target_sources(${name} PRIVATE ".")
    set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
    # Some modules need to include themselves
    target_include_directories(${name} PRIVATE ".")
    baker_cc_apply_properties(${name} ${name})
    return(PROPAGATE name)
endfunction()

function(baker_cc_test)
    baker_cc_binary(${ARGN})
    target_link_libraries(${name} PRIVATE gtest_main gmock)
    add_test(NAME ${name} COMMAND ${name})
endfunction()

function(baker_cc_library_headers)
    baker_parse_metadata(${ARGN})
    add_library(${name} INTERFACE)
    baker_parse_properties(${name})

    if(ARG_export_include_dirs)
        target_include_directories(${name} INTERFACE ${ARG_export_include_dirs})
    endif()
    if(ARG_export_header_lib_headers)
        target_link_libraries(${name} INTERFACE ${ARG_export_header_lib_headers})
    endif()
    if(ARG_export_generated_headers)
        target_link_libraries(${name} INTERFACE ${ARG_export_generated_headers})
    endif()
    if(ARG_export_shared_lib_headers)
        target_link_libraries(${name} INTERFACE ${ARG_export_shared_lib_headers})
    endif()
    if(ARG_whole_static_libs)
        target_link_libraries(${name} INTERFACE ${ARG_whole_static_libs})
    endif()
endfunction()

function(baker_cc_object)
    baker_parse_metadata(${ARGN})

    if(NOT ARG_linker_script)
        add_library(${name} OBJECT)
        target_sources(${name} INTERFACE $<TARGET_OBJECTS:${name}>)
    else()
        # cc_object with linker_script is one object by partial linking of multiple object files
        add_executable(${name})
        # Always enable position independent code
        set_target_properties(${name} PROPERTIES POSITION_INDEPENDENT_CODE ON)
        set_target_properties(${name} PROPERTIES SUFFIX .o ENABLE_EXPORTS ON)
        # Set the linker to use the partial linking option
        target_link_options(${name} PRIVATE -no-pie -nostdlib -Wl,-r)
        target_link_libraries(${name} INTERFACE $<TARGET_FILE:${name}>)
    endif()

    target_sources(${name} PRIVATE ${ARG_srcs})
    baker_parse_properties(${name})
    baker_cc_apply_properties(${name} ${name})
endfunction()

function(baker_cc_library)
    cmake_parse_arguments(ARG "_STATIC_ONLY_;_SHARED_ONLY_" "" "" ${ARGN})
    baker_parse_metadata(${ARG_UNPARSED_ARGUMENTS})

    set(object ".${name}.OBJ")
    add_library(${object} OBJECT)
    target_sources(${object} PRIVATE ${ARG_srcs})
    baker_parse_properties(${object})

    # Some modules need to include themselves
    target_include_directories(${object} PRIVATE ".")

    # hack for header only library, which is hard to determine whether it contains srcs
    target_sources(${object} PUBLIC ".")
    set_target_properties(${object} PROPERTIES LINKER_LANGUAGE CXX)
    # Always enable position independent code
    set_target_properties(${object} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    baker_cc_apply_properties(${object} ${object})

    # Handle static and shared libraries
    # CMake object library will propagate the interface libraries
    # So we can not directly PUBLIC link the object library
    if(NOT ARG__STATIC_ONLY_)
        add_library(${name}-shared SHARED)
        target_link_libraries(${name}-shared PRIVATE ${object})
        target_link_libraries(${name}-shared INTERFACE $<GENEX_EVAL:$<TARGET_PROPERTY:${object},__export_libs>>)
        target_include_directories(${name}-shared INTERFACE $<GENEX_EVAL:$<TARGET_PROPERTY:${object},__export_dirs>>)
        set_target_properties(${name}-shared PROPERTIES PREFIX "" OUTPUT_NAME ${name})
        set_target_properties(${name}-shared PROPERTIES LINKER_LANGUAGE CXX)
        # FIXME: implement #impl apex stub
        add_library(${name}+impl-shared ALIAS ${name}-shared)
    endif()
    if(NOT ARG__SHARED_ONLY_)
        add_library(${name}-static STATIC)
        target_link_libraries(${name}-static PRIVATE ${object})
        target_link_libraries(${name}-static INTERFACE $<GENEX_EVAL:$<TARGET_PROPERTY:${object},__export_libs>>)
        target_include_directories(${name}-static INTERFACE $<GENEX_EVAL:$<TARGET_PROPERTY:${object},__export_dirs>>)
        set_target_properties(${name}-static PROPERTIES PREFIX "" OUTPUT_NAME ${name})
        set_target_properties(${name}-static PROPERTIES LINKER_LANGUAGE CXX)
        # FIXME: implement #impl apex stub
        add_library(${name}+impl-static ALIAS ${name}-static)
    endif()
    # Add alias for static only library
    if(ARG__STATIC_ONLY_)
        add_library(${name} ALIAS ${name}-static)
    else()
        add_library(${name} ALIAS ${name}-shared)
    endif()
    return(PROPAGATE name object)
endfunction()

function(baker_cc_library_static)
    baker_cc_library(_STATIC_ONLY_ ${ARGN})
endfunction()

function(baker_cc_library_shared)
    baker_cc_library(_SHARED_ONLY_ ${ARGN})
endfunction()

function(baker_cc_test_library)
    baker_cc_library(${ARGN})
    target_link_libraries(${object} PRIVATE gtest gmock)
endfunction()