#!/bin/bash

set -e

aidl=$<TARGET_FILE:aidl>
lang=""
output_dir=""
header=""
version=""
min_sdk_version=""
current=true
preprocess=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --lang)
            lang="$2"
            shift 2
            ;;
        --output)
            output_dir="$2"
            shift 2
            ;;
        --version)
            current=false
            version="$2"
            shift 2
            ;;
        --current)
            # This is a special case to handle the 'current' version
            current=true
            shift
            ;;
        --preprocess)
            # This is a special case to handle the 'preprocess' option
            preprocess=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$output_dir" ]; then
    echo "Error: --output is required"
    exit 1
fi
if [ -z "$lang" ] && [ "$preprocess" = false ]; then
    echo "Error: --lang or --preprocess is required"
    exit 1
fi

sources="$<TARGET_PROPERTY:SOURCES>"
if [ "$sources" != "" ]; then
    IFS=';' read -ra sources <<< "$sources"
fi

local_include_dir="$<TARGET_PROPERTY:SOURCE_DIR>/$<TARGET_PROPERTY:_local_include_dir>"
if [ -n "$version" ] && [ "$current" = false ]; then
    directory="$<TARGET_PROPERTY:SOURCE_DIR>/aidl_api/$<TARGET_PROPERTY:_name>/${version}/"
    sources=($(find "$directory" -type f -name "*.aidl"))
    local_include_dir="$<TARGET_PROPERTY:SOURCE_DIR>/aidl_api/$<TARGET_PROPERTY:_name>/${version}/"
fi
local_include_dir=$(realpath "$local_include_dir")

preprocessed="$<TARGET_PROPERTY:_PREPROCESSED_AIDL_>"
if [ "$preprocessed" != "" ]; then
    IFS=';' read -ra preprocessed <<< "$preprocessed"
    args=""
    for f in "${preprocessed[@]}"; do
        args+="-p${f} "
    done
    preprocessed="${args}"
fi

stability="$<TARGET_PROPERTY:_stability>"
if [ -n "$stability" ]; then
    stability="--stability ${stability}"
fi

if [ "${lang}" = "cpp" ]; then
    min_sdk_version="$<TARGET_PROPERTY:_backend_cpp_min_sdk_version>"
    if [ -z "$min_sdk_version" ]; then
        min_sdk_version="$<TARGET_PROPERTY:_min_sdk_version>"
    fi
    if [ -z "$min_sdk_version" ]; then
        min_sdk_version="current"
    fi
    header="-h ${output_dir}/include/"
elif [ "${lang}" = "java" ]; then
    min_sdk_version="$<TARGET_PROPERTY:_backend_java_min_sdk_version>"
    if [ -z "$min_sdk_version" ]; then
        min_sdk_version="$<TARGET_PROPERTY:_min_sdk_version>"
    fi
    sdk_version="$<TARGET_PROPERTY:_backend_java_sdk_version>"
    platform_apis="$<BOOL:$<TARGET_PROPERTY:_backend_java_platform_apis>>"
    if [ "$platform_apis" == 0 ] && [ -z "$sdk_version" ]; then
        sdk_version="system_current"
    fi
    if [ -n "$sdk_version" ] && [ -z "$min_sdk_version" ]; then
        # sdk_version="foo_ver", make min_sdk_version="ver"
        IFS='_' read -ra parts <<< "$sdk_version"
        min_sdk_version="${parts[-1]}"
    fi
    if [ "$platform_apis" == 1 ]; then
        min_sdk_version="platform_apis"
    elif [ -z "$min_sdk_version" ]; then
        min_sdk_version="current"
    fi
fi

structured=""
if [ -n "$version" ]; then
    structured="--structured"
    version="--version ${version}"
fi

if [ "$preprocess" = true ]; then
    ${aidl} --preprocess \
        ${output_dir}/$<TARGET_PROPERTY:NAME>.preprocessed.aidl \
        ${preprocessed} \
        ${include_dirs} \
        -I${local_include_dir} \
        ${structured} \
        ${stability} \
        "${sources[@]}"
else
    ${aidl} --lang=${lang} \
        -o ${output_dir}/ \
        ${header} \
        ${preprocessed} \
        -N${local_include_dir} \
        --min_sdk_version ${min_sdk_version} \
        ${structured} \
        ${version} \
        ${stability} \
        "${sources[@]}"
fi
