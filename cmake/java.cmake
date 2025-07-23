find_package(Java REQUIRED COMPONENTS Development)
if(Java_FOUND)
    message(STATUS "Java ${Java_VERSION} found: ${Java_JAVAC_EXECUTABLE}")
endif()

if(EXISTS "${CMAKE_SOURCE_DIR}/tools/metalava")
    # Build metalava
    include(ExternalProject)
    ExternalProject_Add(metalava_build
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/tools/metalava
        BUILD_IN_SOURCE TRUE
        # Disable JAVA_HOME export in gradlew
        CONFIGURE_COMMAND sed -i "s/^export JAVA_HOME=/#export JAVA_HOME=/" ${CMAKE_SOURCE_DIR}/tools/metalava/gradlew
        BUILD_COMMAND OUT_DIR=${CMAKE_BINARY_DIR}/ ./gradlew installDist
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS "${CMAKE_BINARY_DIR}/metalava/metalava/build/install/metalava/bin/metalava"
    )
    # Import the built binary
    add_executable(metalava IMPORTED GLOBAL)
    add_dependencies(metalava metalava_build)
    set_target_properties(metalava PROPERTIES IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/metalava/metalava/build/install/metalava/bin/metalava)
endif()

if(EXISTS "${CMAKE_SOURCE_DIR}/external/turbine")
    # Build turbine
    include(ExternalProject)
    ExternalProject_Add(turbine_build
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/external/turbine
        BUILD_IN_SOURCE TRUE
        CONFIGURE_COMMAND ""
        BUILD_COMMAND mvn package
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS "<SOURCE_DIR>/target/turbine-HEAD-SNAPSHOT-all-deps.jar"
    )
    # Import the built binary
    add_executable(turbine IMPORTED GLOBAL)
    add_dependencies(turbine turbine_build)
    set_target_properties(turbine PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/external/turbine/target/turbine-HEAD-SNAPSHOT-all-deps.jar)
endif()


function(baker_add_metalava lib name src)
    add_library(${lib} OBJECT "${BAKER_DUMMY_C_SOURCE}")
    target_link_libraries(${lib} PRIVATE ${src})
    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.metalava.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/metalava.template.sh" TARGET ${src})
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
        # Clean up previous build artifacts
        COMMAND ${CMAKE_COMMAND} -E rm -rf
            "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/"
        # Run metalava to generate stubs and classpath
        COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${name}.metalava.sh
            --stubs "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/"
        COMMAND find "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/" -name "*.java" -type f > "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
        DEPENDS ${lib} metalava
        VERBATIM
    )
    target_sources(${lib} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list")
    # javac accepts @<file> as a list of source files, so we can use it to pass the list of stubs
    set_target_properties(${lib} PROPERTIES INTERFACE__STUBS_SOURCES_ "@${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list")
    set_target_properties(${lib} PROPERTIES TRANSITIVE_COMPILE_PROPERTIES "_STUBS_SOURCES_")
endfunction()


function(baker_java_api_library)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_libs>)
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_api_contributions>)

    add_library(${name} OBJECT "${BAKER_DUMMY_C_SOURCE}")
    target_link_libraries(${name} PRIVATE ${src})

    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.metalava.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/metalava.template.sh" TARGET ${src})
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar" "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
        # Run metalava to generate stubs and classpath
        COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${name}.metalava.sh
            --stubs "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/"
        COMMAND find "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/stubs/" -name "*.java" -type f > "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
        # Clean up previous build artifacts
        COMMAND ${CMAKE_COMMAND} -E rm -rf
            "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
            "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
        # Compile the Java sources and package them into a JAR
        COMMAND ${Java_JAVAC_EXECUTABLE}
            "@${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list"
            -source 1.8 -target 1.8
            -classpath "$<TARGET_PROPERTY:${name},_CLASSPATH_>"
            -d "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
        COMMAND ${Java_JAR_EXECUTABLE}
            cf "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
            -C "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/" .
        DEPENDS ${name} metalava
        VERBATIM
    )
    target_sources(${name} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
endfunction()

function(baker_java_sdk_library)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_system_modules>)
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_merge_inclusion_annotations_dirs>)

    # Add {.public.stubs.source}
    baker_canonicalize_name(public_stubs_source "${name}{.public.stubs.source}")
    baker_add_metalava(${public_stubs_source} ${name} ${src})

    # Add .stubs
    set(stubs "${name}.stubs")
    add_library(${stubs} OBJECT "${BAKER_DUMMY_C_SOURCE}")
    target_link_libraries(${stubs} PRIVATE ${src})
    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.turbine.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/turbine.template.sh" TARGET ${src})
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${stubs}.jar"
        # Run metalava to generate stubs and classpath
        COMMAND ${CMAKE_COMMAND} -E env Java_JAVA_EXECUTABLE=${Java_JAVA_EXECUTABLE} --
            ${CMAKE_CURRENT_BINARY_DIR}/${name}.turbine.sh
            --sources "$<TARGET_PROPERTY:${public_stubs_source},INTERFACE__STUBS_SOURCES_>"
            --output "${CMAKE_CURRENT_BINARY_DIR}/${stubs}.jar"
        DEPENDS ${public_stubs_source} turbine ${CMAKE_CURRENT_BINARY_DIR}/gen/${name}.metalava.list
        VERBATIM
    )
    target_sources(${stubs} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${stubs}.jar")
    set_target_properties(${stubs} PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_CURRENT_BINARY_DIR}/${stubs}.jar")
    set_target_properties(${stubs} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")

    # Add api_contribution, which will be used in java_api_library
    set(api_contribution "${name}.stubs.source.api.contribution")
    add_library(${api_contribution} INTERFACE)
    set(api_dir "$<IF:$<BOOL:$<TARGET_PROPERTY:${src},_api_dir>>,$<TARGET_PROPERTY:${src},_api_dir>,api>")
    target_sources(${api_contribution} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/${api_dir}/current.txt")
    # Inherit droiddoc options, flags and args from the source target
    set_target_properties(${api_contribution} PROPERTIES
        INTERFACE__droiddoc_options "$<TARGET_PROPERTY:${src},_droiddoc_options>"
        INTERFACE__flags "$<TARGET_PROPERTY:${src},_flags>"
        INTERFACE__args "$<TARGET_PROPERTY:${src},_args>"
    )
    set_target_properties(${api_contribution} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_droiddoc_options" "_flags" "_args")
endfunction()

function(baker_java_system_modules)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})

    # System modules do not export libs to the classpath
    # so use a interface library to collect all libs classpath
    add_library(.${name}.LINK INTERFACE)
    target_link_libraries(.${name}.LINK INTERFACE $<TARGET_PROPERTY:${src},_libs>)

    add_library(${name} OBJECT "${BAKER_DUMMY_C_SOURCE}")
    target_link_libraries(${name} PRIVATE ${src})
    # Export the classpath of libs to _LINKED_CLASSPATH_
    set_target_properties(${name} PROPERTIES INTERFACE__LINKED_CLASSPATH_ "$<TARGET_PROPERTY:.${name}.LINK,INTERFACE__CLASSPATH_>")
    set(outputs
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/modules/module.jar"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/modules/module-info.class"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/modules/jmod/java.base.jmod"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/system/lib/jrt-fs.jar"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/system/lib/modules"
        "${CMAKE_CURRENT_BINARY_DIR}/${name}/system/release"
    )
    add_custom_command(
        OUTPUT ${outputs}
        COMMAND ${CMAKE_COMMAND} -E env
            Java_JAVAC_EXECUTABLE=${Java_JAVAC_EXECUTABLE}
            Java_JAR_EXECUTABLE=${Java_JAR_EXECUTABLE}
            ZIPMERGE=${CMAKE_SOURCE_DIR}/cmake/zipmerge.py
            --
        ${CMAKE_SOURCE_DIR}/cmake/java_system_modules.sh
            --jars "$<GENEX_EVAL:$<TARGET_PROPERTY:${name},INTERFACE__LINKED_CLASSPATH_>>"
            --outDir "${CMAKE_CURRENT_BINARY_DIR}/${name}/"
            --moduleVersion "${Java_VERSION_STRING}"
        DEPENDS ${name} $<TARGET_PROPERTY:${src},_libs>
        VERBATIM
    )
    target_sources(${name} PRIVATE ${outputs})
    set_target_properties(${name} PROPERTIES INTERFACE__SYSTEM_MODULES_PATH_ "${CMAKE_CURRENT_BINARY_DIR}/${name}/system/")
    # For java_system_modules(a) -> java_library(b) -> java_system_modules(c)
    # If we use TRANSITIVE_LINK_PROPERTIES, then c will also inherit _SYSTEM_MODULES_PATH_ from a
    # But we only want the _SYSTEM_MODULES_PATH_ from c itself
    # So we have to use TRANSITIVE_COMPILE_PROPERTIES instead
    set_target_properties(${name} PROPERTIES TRANSITIVE_COMPILE_PROPERTIES "_SYSTEM_MODULES_PATH_")
    set_target_properties(${name} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_LINKED_CLASSPATH_")
endfunction()

function(baker_java_library)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})
    # TODO: may need to apply sources transform to {openjdk9: { srcs: ["..."] } as well
    target_sources(${src} INTERFACE "$<LIST:TRANSFORM,$<TARGET_PROPERTY:${src},_openjdk9_srcs>,PREPEND,${CMAKE_CURRENT_SOURCE_DIR}/>")
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_libs>)
    target_link_libraries(${src} INTERFACE $<TARGET_PROPERTY:${src},_system_modules>)

    add_library(${name} OBJECT "${BAKER_DUMMY_C_SOURCE}")
    target_link_libraries(${name} PRIVATE ${src})

    # Use a interface library to collect all static_libs classpath
    add_library(.${name}.LINK INTERFACE)
    target_link_libraries(.${name}.LINK INTERFACE $<TARGET_PROPERTY:${src},_static_libs>)
    set_target_properties(${src} PROPERTIES _STATIC_CLASSPATH_ "$<TARGET_PROPERTY:.${name}.LINK,INTERFACE__CLASSPATH_>")

    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.java_library.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/java_library.template.sh" TARGET ${src})
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
        # Clean up previous build artifacts
        COMMAND ${CMAKE_COMMAND} -E rm -rf
            "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
            "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
        # Compile the Java sources and package them into a JAR
        COMMAND ${CMAKE_COMMAND} -E env Java_JAVAC_EXECUTABLE=${Java_JAVAC_EXECUTABLE}
            ${CMAKE_CURRENT_BINARY_DIR}/${name}.java_library.sh
            -d "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/"
        COMMAND ${Java_JAR_EXECUTABLE}
            cf "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
            -C "${CMAKE_CURRENT_BINARY_DIR}/gen/${name}/classes/" .
        # Merge the JARs from the static_libs
        COMMAND ${CMAKE_SOURCE_DIR}/cmake/zipmerge.py --append
            "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
            $<TARGET_PROPERTY:.${name}.LINK,INTERFACE__CLASSPATH_>
        DEPENDS ${name} ${CMAKE_CURRENT_BINARY_DIR}/${name}.java_library.sh $<TARGET_PROPERTY:${src},_static_libs>
        # --patch-module java.base=. relies on the top level directory
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        VERBATIM
        COMMAND_EXPAND_LISTS
    )

    target_sources(${name} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar")
    set_target_properties(${name} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")

    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.dex.sh" INPUT "${CMAKE_SOURCE_DIR}/cmake/dex.template.sh" TARGET ${src})
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.dex.jar"
        COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${name}.dex.sh
            --source "${CMAKE_CURRENT_BINARY_DIR}/${name}.jar"
            --output "${CMAKE_CURRENT_BINARY_DIR}/${name}.dex.jar"
        DEPENDS ${name} ${CMAKE_CURRENT_BINARY_DIR}/${name}.jar d8
        VERBATIM
    )
    # TODO: zipalign
    target_sources(${name} PRIVATE "$<$<BOOL:$<TARGET_PROPERTY:${src},_installable>>:${CMAKE_CURRENT_BINARY_DIR}/${name}.dex.jar>")
endfunction()

function(baker_droiddoc_exported_dir)
    baker_parse_metadata(${ARGN})

    add_library(${name} INTERFACE)
    baker_parse_properties(${name})
    target_sources(${name} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${name})

    set_target_properties(${name} PROPERTIES INTERFACE__ANNOTATION_DIR_ "${CMAKE_CURRENT_SOURCE_DIR}/$<TARGET_PROPERTY:${name},_path>")
    set_target_properties(${name} PROPERTIES TRANSITIVE_COMPILE_PROPERTIES "_ANNOTATION_DIR_")
endfunction()

function(baker_java_import)
    baker_parse_metadata(${ARGN})

    add_library(${name} INTERFACE)
    baker_parse_properties(${name})
    target_sources(${name} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${name})

    set_target_properties(${name} PROPERTIES INTERFACE__CLASSPATH_ "${CMAKE_CURRENT_SOURCE_DIR}/$<TARGET_PROPERTY:${name},_jars>")
    set_target_properties(${name} PROPERTIES TRANSITIVE_LINK_PROPERTIES "_CLASSPATH_")
endfunction()

function(baker_droidstubs)
    baker_parse_metadata(${ARGN})

    set(src ".${name}.SRC")
    add_library(${src} INTERFACE)
    baker_parse_properties(${src})
    target_sources(${src} INTERFACE ${ARG_srcs})
    baker_apply_sources_transform(${src})

    # Special flags for droidstubs
    # See build/soong/java/droidstubs.go
    set_property(TARGET ${src} APPEND PROPERTY _flags "--exclude-documentation-from-stubs")
    baker_add_metalava(${name} ${name} ${src})
endfunction()