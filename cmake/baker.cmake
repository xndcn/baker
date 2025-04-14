include(${CMAKE_CURRENT_LIST_DIR}/sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/defaults.cmake)

function(baker dir)
    cmake_parse_arguments(BAKER "EXCLUDE_FROM_ALL" "OUTPUT" "" ${ARGN})

    if(SKIP_BAKER)
        message(STATUS "Skipping baker execution for ${dir} (SKIP_BAKER=ON)")
    else()
        message(STATUS "Processing Android.bp in ${dir}")

        set(baker_command baker "${dir}")
        # If OUTPUT is set, do not add recursive
        if(BAKER_OUTPUT)
            list(APPEND baker_command "--output" "${BAKER_OUTPUT}")
        else()
            list(APPEND baker_command "--recursive")
        endif()

        execute_process(
            COMMAND ${baker_command}
            RESULT_VARIABLE baker_result
            OUTPUT_VARIABLE baker_output
            ERROR_VARIABLE baker_error
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        )

        if(baker_result EQUAL 0)
            message(STATUS "Successfully converted blueprint in ${dir}")
        else()
            message(FATAL_ERROR "Failed to convert blueprint in ${dir}: ${baker_error}")
        endif()
    endif()

    # Check for custom output path or default location
    set(cmake_list_path "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/CMakeLists.txt")
    if(BAKER_OUTPUT)
        set(cmake_list_path "${CMAKE_CURRENT_SOURCE_DIR}/${BAKER_OUTPUT}")
    endif()

    if(EXISTS "${cmake_list_path}")
        if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${dir}")
            if(BAKER_EXCLUDE_FROM_ALL)
                add_subdirectory(${dir} EXCLUDE_FROM_ALL)
            else()
                add_subdirectory(${dir})
            endif()
        endif()
    else()
        message(FATAL_ERROR "Failed to find CMakeLists.txt at ${cmake_list_path}")
    endif()
endfunction()

function(baker_include_build build)
    foreach(file ${build})
        # Process each file with baker function
        baker(${file} OUTPUT "${file}.cmake")

        # Include the generated cmake file
        include("${file}.cmake")
    endforeach()
endfunction()


function(baker_apply_properties target dependency)
    # Process include directories
    set(include_dirs "")
    set(export_include_dirs "")
    list(APPEND include_dirs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_local_include_dirs>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
    foreach(dir "include_dirs")
        list(APPEND include_dirs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_${dir}>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
        list(APPEND export_include_dirs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_${dir}>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>)
    endforeach()
    # Process header libraries
    set(link_libs "")
    set(export_link_libs "")
    foreach(lib "header_libs" ; "header_lib_headers")
        list(APPEND link_libs $<TARGET_PROPERTY:${dependency},_${lib}>)
        list(APPEND export_link_libs $<TARGET_PROPERTY:${dependency},_export_${lib}>)
    endforeach()
    # Process shared libraries
    foreach(lib "shared_libs")
        list(APPEND link_libs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_${lib}>,APPEND,-shared>)
        list(APPEND export_link_libs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_${lib}>,APPEND,-shared>)
    endforeach()
    # Process static libraries
    foreach(lib "static_libs")
        list(APPEND link_libs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_${lib}>,APPEND,-static>)
        list(APPEND export_link_libs $<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_${lib}>,APPEND,-static>)
    endforeach()
    # Process whole_static_libs
    list(APPEND link_libs $<LINK_LIBRARY:WHOLE_ARCHIVE,$<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_whole_static_libs>,APPEND,-static>>)
    list(APPEND export_link_libs $<LINK_LIBRARY:WHOLE_ARCHIVE,$<LIST:TRANSFORM,$<TARGET_PROPERTY:${dependency},_export_whole_static_libs>,APPEND,-static>>)
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
endfunction(baker_apply_properties)