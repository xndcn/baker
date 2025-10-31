#!/bin/env bash

# Use generator expression to avoid special characters in the cmd
cmd=$(cat <<'EOF'
$<TARGET_PROPERTY:_cmd>
EOF
)
# Unescape the content of the command file
cmd=$(echo -e "${cmd}")

genDir=""
output_extension=""
outs=()
tools=()
tool_files=()

# Use generator expression to get the source files to avoid too long arguments list
srcs="$<PATH:RELATIVE_PATH,$<TARGET_PROPERTY:INTERFACE_SOURCES>,$<TARGET_PROPERTY:SOURCE_DIR>>"
IFS=';' read -ra srcs <<< "$srcs"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --output_extension)
            output_extension="$2"
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

if [ -z "$outs" ] && [ -z "$output_extension" ]; then
    echo "Error: --outs or --output_extension is required"
    exit 1
fi

# If output_extension is provided, generate outs based on srcs
# Currently not used, since add_custom_command() need to know the output files
if [ -n "$output_extension" ]; then
    outs=()
    for src in "${srcs[@]}"; do
        # Get the base name of the source file without extension
        base_name=$(basename "$src")
        # Replace the extension with the output_extension
        out="${base_name%.*}.$output_extension"
        outs+=("$out")
    done
fi

# Transform cmd
# FIXME: check how to handle $(location) without arguments
cmd="${cmd//\$(location)/.}"
cmd="${cmd//\$(in)/\$\{in\}}"
cmd="${cmd//\$(out)/\$\{out\}}"
cmd="${cmd//\$(genDir)/\$\{genDir\}}"

# Re-create output directory
rm -rf "$genDir"
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
        # File doesn't start with ":", look for it in tool_files firstly
        for tool_file in "${tool_files[@]}"; do
        if [[ "${tool_file#./}" == "${file}" ]]; then
            echo "$tool_file"
            return 0
        fi
        done
        # Then find the tool in the tools array
        for tool in "${tools[@]}"; do
        if [[ "$(basename "$tool")" == "$file" ]]; then
            echo "$tool"
            return 0
        fi
        done
        echo "Error: File '$file' not found in tool_files or tools" >&2
        return 1
    fi
}

# Process each source file individually
for i in "${!outs[@]}"; do
    in="${srcs[$i]}"
    if [ ${#outs[@]} -eq 1 ]; then
        # When there's only one output, join all sources with spaces
        in=$(printf "%s " "${srcs[@]}")
        in=${in% } # Remove trailing space
    fi
    out=${genDir}/"${outs[$i]}"
    # Create the output directory if it doesn't exist
    mkdir -p "$(dirname "$out")"
    # Evaluate the command, like $(location foo) ${in} > ${out}
    eval "$cmd"
done