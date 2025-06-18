#!/bin/bash

set -e

javac=${Java_JAVAC_EXECUTABLE}

# Parse arguments
system_modules="$<TARGET_PROPERTY:_system_modules>"
if [ "$system_modules" != "" ]; then
    if [ "$system_modules" != "none" ]; then
        system_modules="--system=$<TARGET_PROPERTY:INTERFACE__SYSTEM_MODULES_PATH_>"
    else
        system_modules="--system=none"
    fi
fi

source_target="$<TARGET_PROPERTY:_java_version>"
if [ "$source_target" != "" ]; then
    source_target="-source ${source_target} -target ${source_target}"
fi

jars=""
classpath="$<TARGET_PROPERTY:INTERFACE__CLASSPATH_>"
if [ "$classpath" != "" ]; then
    IFS=';' read -ra jars <<< "$classpath"
    # Join jars elements with ':'
    jars="$(IFS=: ; echo "${jars[*]}")"
    classpath="-classpath ${jars}"
fi

sources="$<TARGET_PROPERTY:INTERFACE_SOURCES>"
if [ "$sources" != "" ]; then
    IFS=';' read -ra sources <<< "$sources"

    # Create new rsp file to store file list
    rsp="$<TARGET_PROPERTY:NAME>.sources.rsp"
    > "${rsp}"  # Create the file
    # Process each source file
    for filepath in "${sources[@]}"; do
        if [[ "$filepath" != @* ]]; then
            echo "$filepath" >> "${rsp}"
        fi
    done
    sources="@${rsp}"
fi

stubs_sources="$<TARGET_PROPERTY:INTERFACE__STUBS_SOURCES_>"
if [ "$stubs_sources" != "" ]; then
    IFS=';' read -ra stubs_sources <<< "$stubs_sources"
    sources="${sources} ${stubs_sources[*]}"
fi

# TODO: handle patch_module sources in different directories
patch_module="$<TARGET_PROPERTY:_patch_module>"
if [ "$patch_module" != "" ]; then
    patch_module="--patch-module ${patch_module}=$<TARGET_PROPERTY:SOURCE_DIR>"
    if [ "$jars" != "" ]; then
        patch_module="${patch_module}:${jars}"
    fi
fi

# Check java_version
java_version="$<TARGET_PROPERTY:_java_version>"
if [ "$java_version" == "1.8" ]; then
    # For Java 8, ignore patch-module and system modules
    patch_module=""
    system_modules=""
fi

${javac} \
    ${system_modules} \
    ${source_target} \
    ${patch_module} \
    ${classpath} \
    ${sources} \
    $@