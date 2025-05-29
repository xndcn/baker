#!/bin/bash

set -e

metalava=$<TARGET_PROPERTY:metalava,IMPORTED_LOCATION>
classpath=""
source_files=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stubs)
            stubs_dir="$2"
            shift 2
            ;;
        --classpath)
            if [ -n "$2" ]; then
                # Split classpath into arrays
                IFS=';' read -ra classpath <<< "$2"
                classpath="--classpath ${classpath[@]}"
            fi
            shift 2
            ;;
        --source-files)
            if [ -n "$2" ]; then
                # Split source-files into arrays
                IFS=';' read -ra source_files <<< "$2"
                source_files="--source-files ${source_files[@]}"
            fi
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$stubs_dir" ]; then
    echo "Error: --stubs is required"
    exit 1
fi

# Use multi-level GENEX_EVAL to handle nested properties
${metalava} \
    ${source_files} \
    ${classpath} \
    --stubs "${stubs_dir}" \
    --color --quiet --format=v2 \
    $<JOIN:$<TARGET_PROPERTY:_droiddoc_options>, > \
    $<JOIN:$<TARGET_PROPERTY:_args>, > \
    $<JOIN:$<TARGET_PROPERTY:_flags>, > \
    --hide UnresolvedImport \
    --hide HiddenSuperclass --hide BroadcastBehavior --hide DeprecationMismatch \
    --hide MissingPermission --hide SdkConstant --hide Todo \
    --error-when-new-category Documentation --hide Deprecated \
    --hide IntDef --hide Nullable

# TODO: add api checking