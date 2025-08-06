#!/bin/bash

set -e

javac=${Java_JAVAC_EXECUTABLE}
output_dir=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d)
            output_dir="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$output_dir" ]; then
    echo "Error: -d is required"
    exit 1
fi

system_modules="$<TARGET_PROPERTY:_system_modules>"
if [ "$system_modules" != "" ]; then
    if [ "$system_modules" != "none" ]; then
        system_modules="--system=$<TARGET_PROPERTY:INTERFACE__SYSTEM_MODULES_PATH_>"
    else
        system_modules="--system=none"
    fi
fi

# Check java_version
java_version="$<TARGET_PROPERTY:_java_version>"
# Java 1.7 is deprecated, treat it as 1.8
if [ "$java_version" == "1.7" ]; then
    java_version="1.8"
fi

source_target="${java_version}"
if [ "$source_target" != "" ]; then
    source_target="-source ${source_target} -target ${source_target}"
fi

jars=""
classpath="$<JOIN:$<GENEX_EVAL:$<TARGET_PROPERTY:INTERFACE__CLASSPATH_>;$<TARGET_PROPERTY:_STATIC_CLASSPATH_>>,;>"
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
    patch_module="--patch-module ${patch_module}=."
    if [ "$jars" != "" ]; then
        patch_module="${patch_module}:${jars}"
    fi
fi

if [ "$java_version" == "1.8" ]; then
    # For Java 8, ignore patch-module and system modules
    patch_module=""
    system_modules=""
fi

# is_stubs_module may be ON or TRUE, using BOOL to handle both cases
is_stubs_module="$<BOOL:$<TARGET_PROPERTY:_is_stubs_module>>"
if [ "$is_stubs_module" == "1" ] && [ -z "$sources" ]; then
    echo "Skip compiling stubs module without sources"
    mkdir -p "${output_dir}"
    exit 0
fi

${javac} \
    ${system_modules} \
    ${source_target} \
    ${patch_module} \
    ${classpath} \
    ${sources} \
    -d "${output_dir}"
