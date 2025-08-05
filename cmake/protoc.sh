#!/bin/bash

set -e

protoc=${PROTOC_EXECUTABLE}
source_dir=""
output_dir=""
protos=""
language=""
plugin=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --source)
            source_dir="$2"
            shift 2
            ;;
        --output)
            output_dir="$2"
            shift 2
            ;;
        --protos)
            if [ -n "$2" ]; then
                # Split protos into arrays
                IFS=';' read -ra protos <<< "$2"
                protos="$(IFS=' ' ; echo "${protos[*]}")"
            fi
            shift 2
            ;;
        --language)
            language="$2"
            shift 2
            ;;
        --plugin)
            plugin="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$source_dir" ] || [ -z "$output_dir" ] || [ -z "$protos" ] || [ -z "$plugin" ] || [ -z "$language" ]; then
    echo "Error: --source, --output, --protos, --plugin, --language are required"
    exit 1
fi


# Create the output directory if it doesn't exist
mkdir -p "${output_dir}"

${protoc} \
    --${language}_out=:"${output_dir}" \
    --plugin=${plugin} \
    -I ${source_dir} \
    ${protos}