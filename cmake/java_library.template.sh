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

classpath="$<TARGET_PROPERTY:INTERFACE__CLASSPATH_>"
if [ "$classpath" != "" ]; then
    IFS=';' read -ra classpath <<< "$classpath"
    # Join classpath elements with ':'
    classpath="$(IFS=: ; echo "${classpath[*]}")"
    classpath="-classpath ${classpath}"
fi

sources="$<TARGET_PROPERTY:INTERFACE_SOURCES>"
if [ "$sources" != "" ]; then
    IFS=';' read -ra sources <<< "$sources"
    # Join source files with ' '
    sources="$(IFS=' ' ; echo "${sources[*]}")"
fi

# TODO: handle patch_module sources in different directories
patch_module="$<TARGET_PROPERTY:_patch_module>"
if [ "$patch_module" != "" ]; then
    patch_module="--patch-module ${patch_module}=$<TARGET_PROPERTY:SOURCE_DIR>"
fi

${javac} \
    ${system_modules} \
    ${source_target} \
    ${patch_module} \
    ${classpath} \
    ${sources} \
    $@