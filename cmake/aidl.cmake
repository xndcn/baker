# Function to generate C++ files from AIDL sources
function(add_aidl_library)
  # Parse arguments
  set(options)
  set(oneValueArgs TARGET OUTPUT_DIR LANG)
  set(multiValueArgs SRCS INCLUDE_DIRS)
  cmake_parse_arguments(AIDL "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Validate required arguments
  if(NOT DEFINED AIDL_TARGET)
    message(FATAL_ERROR "add_aidl_library: TARGET not specified")
  endif()

  if(NOT DEFINED AIDL_SRCS)
    message(FATAL_ERROR "add_aidl_library: SRCS not specified")
  endif()
  
  if(NOT DEFINED AIDL_LANG)
    message(FATAL_ERROR "add_aidl_library: LANG not specified")
  endif()

  # Set defaults for optional arguments
  if(NOT DEFINED AIDL_OUTPUT_DIR)
    set(AIDL_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/aidl")
  endif()

  # Find the AIDL compiler
  find_program(AIDL_EXECUTABLE aidl)

  if(NOT AIDL_EXECUTABLE)
    message(FATAL_ERROR "add_aidl_library: AIDL compiler not found. Make sure it's in your PATH or set AIDL_EXECUTABLE.")
  endif()

  # Create the output directory
  file(MAKE_DIRECTORY ${AIDL_OUTPUT_DIR})

  # Process each AIDL file
  set(AIDL_GENERATED_SOURCES)

  foreach(AIDL_SRC ${AIDL_SRCS})
    get_filename_component(AIDL_SRC_ABSOLUTE ${AIDL_SRC} ABSOLUTE)
    get_filename_component(AIDL_FILE_NAME ${AIDL_SRC} NAME_WE)

    # Calculate output files
    set(AIDL_GEN_CPP "${AIDL_OUTPUT_DIR}/${AIDL_FILE_NAME}.cpp")
    set(AIDL_GEN_H "${AIDL_OUTPUT_DIR}/${AIDL_FILE_NAME}.h")

    # Generate include flags
    set(INCLUDE_FLAGS)
    foreach(INCLUDE_DIR ${AIDL_INCLUDE_DIRS})
      list(APPEND INCLUDE_FLAGS "-I${INCLUDE_DIR}")
    endforeach()

    # Add custom command to generate files from AIDL
    add_custom_command(
      OUTPUT ${AIDL_GEN_CPP} ${AIDL_GEN_H}
      COMMAND ${AIDL_EXECUTABLE}
      ARGS --lang=${AIDL_LANG} ${INCLUDE_FLAGS} -o${AIDL_OUTPUT_DIR} ${AIDL_SRC_ABSOLUTE}
      DEPENDS ${AIDL_SRC_ABSOLUTE}
      COMMENT "Generating ${AIDL_LANG} files from AIDL: ${AIDL_SRC}"
      VERBATIM
    )

    list(APPEND AIDL_GENERATED_SOURCES ${AIDL_GEN_CPP})
  endforeach()

  # Create a library with the generated files
  add_library(${AIDL_TARGET} STATIC ${AIDL_GENERATED_SOURCES})
  target_include_directories(${AIDL_TARGET} PUBLIC ${AIDL_OUTPUT_DIR})

  # Make the generated sources available to the parent scope
  set(${AIDL_TARGET}_SOURCES ${AIDL_GENERATED_SOURCES} PARENT_SCOPE)
  set(${AIDL_TARGET}_OUTPUT_DIR ${AIDL_OUTPUT_DIR} PARENT_SCOPE)
endfunction()
