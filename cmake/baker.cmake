include(${CMAKE_CURRENT_LIST_DIR}/sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/defaults.cmake)

function(baker dir)
    cmake_parse_arguments(BAKER "EXCLUDE_FROM_ALL" "" "" ${ARGN})

    if(SKIP_BAKER)
        message(STATUS "Skipping baker execution for ${dir} (SKIP_BAKER=ON)")
    else()
        message(STATUS "Processing Android.bp in ${dir}")
        execute_process(
            COMMAND baker "${dir}" "--recursive"
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

    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/CMakeLists.txt")
        message(STATUS "Adding subdirectory: ${dir}")
        if(BAKER_EXCLUDE_FROM_ALL)
            add_subdirectory(${dir} EXCLUDE_FROM_ALL)
        else()
            add_subdirectory(${dir})
        endif()
    else()
        message(FATAL_ERROR "Failed to add subdirectory ${dir}")
    endif()
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
endfunction(baker_apply_properties)