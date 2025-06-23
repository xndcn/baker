#!/bin/bash

set -e

d8=$<TARGET_PROPERTY:d8,IMPORTED_LOCATION>
output_dir=""
source_jar=""
d8flags="-JDcom.android.tools.r8.emitRecordAnnotationsInDex -JDcom.android.tools.r8.emitPermittedSubclassesAnnotationsInDex"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            output_dir="$2"
            shift 2
            ;;
        --source)
            source_jar="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$output_dir" ] || [ -z "$source_jar" ]; then
    echo "Error: --output and --source are required"
    exit 1
fi

libs="$<TARGET_PROPERTY:INTERFACE__CLASSPATH_>"
if [ "$libs" != "" ]; then
    IFS=';' read -ra libs <<< "$libs"
    lib_args=""
    for jar in "${libs[@]}"; do
        lib_args+="--lib $jar "
    done
    libs="$lib_args"
fi

dxflags="$<TARGET_PROPERTY:_dxflags>"
if [ "$dxflags" != "" ]; then
    IFS=';' read -ra dxflags <<< "$dxflags"

    # Remove unsupported DX flags: "--core-library", "--dex", "--multi-dex"
    # See build/soong/java/dex.go
    dxflags=("${dxflags[@]/--core-library}")
    dxflags=("${dxflags[@]/--dex}")
    dxflags=("${dxflags[@]/--multi-dex}")

    dxflags="$(IFS=' ' ; echo "${dxflags[*]}")"
fi

min_api="$<TARGET_PROPERTY:_min_sdk_version>"
if [ "$min_api" != "" ]; then
    min_api="--min-api ${min_api}"
fi

bash ${d8} \
    ${d8flags} \
    ${dxflags} \
    ${min_api} \
    ${libs} \
    --output ${output_dir} \
    --no-dex-input-jar ${source_jar}