#!/bin/env bash

# Parse arguments
cmd=""
genDir=""
outs=()
srcs=()
tools=()
tool_files=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cmd)
            cmd="$2"
            shift 2
            ;;
        --genDir)
            genDir="$2"
            shift 2
            ;;
        --outs)
            if [ -n "$2" ]; then
                # Split outs into arrays
                IFS=';' read -ra outs <<< "$2"
            fi
            shift 2
            ;;
        --srcs)
            if [ -n "$2" ]; then
                # Split srcs into arrays
                IFS=';' read -ra srcs <<< "$2"
            fi
            shift 2
            ;;
        --tools)
            if [ -n "$2" ]; then
                # Split tools into an array
                IFS=';' read -ra tools <<< "$2"
            fi
            shift 2
            ;;
        --tool_files)
            if [ -n "$2" ]; then
                # Split tool_files into an array
                IFS=';' read -ra tool_files <<< "$2"
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
if [ -z "$cmd" ]; then
    echo "Error: --cmd is required"
    exit 1
fi

if [ -z "$genDir" ]; then
    echo "Error: --genDir is required"
    exit 1
fi

if [ -z "$outs" ]; then
    echo "Error: --outs is required"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$genDir"

# Function to determine file location
location() {
    local file="$1"

    if [[ "$file" == :* ]]; then
        # File starts with ":", look for it in tools
        local tool_name="${file#:}"
        # Find the tool in the tools array
        for tool in "${tools[@]}"; do
        if [[ "$(basename "$tool")" == "$tool_name" ]]; then
            echo "$tool"
            return 0
        fi
        done

        echo "Error: Tool '$tool_name' not found in tools" >&2
        return 1
    else
        # File doesn't start with ":", look for it in tool_files
        for tool_file in "${tool_files[@]}"; do
        if [[ "$(basename "$tool_file")" == "$file" ]]; then
            echo "$tool_file"
            return 0
        fi
        done
        echo "Error: File '$file' not found in tool_files" >&2
        return 1
    fi
}

# Process each source file
for i in "${!outs[@]}"; do
    in="${srcs[$i]}"
    out=${genDir}/"${outs[$i]}"

    # Evaluate the command, like $(location foo) ${in} > ${out}
    eval "$cmd"
done