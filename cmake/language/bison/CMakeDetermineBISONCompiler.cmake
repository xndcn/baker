find_package(BISON)

message(STATUS "xxx ${CMAKE_CURRENT_LIST_DIR} -> ${CMAKE_PLATFORM_INFO_DIR}")

configure_file(${CMAKE_CURRENT_LIST_DIR}/CMakeBISONCompiler.cmake.in
    ${CMAKE_PLATFORM_INFO_DIR}/CMakeBISONCompiler.cmake
    @ONLY
)