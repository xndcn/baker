message(WARNING "Entering bison.cmake")

set(CMAKE_BISON_COMPILE_OBJECT
            "<CMAKE_Cython_COMPILER> -o <OBJECT>.c <SOURCE>"
            "${CMAKE_C_COMPILE_OBJECT_replaced}"
    )