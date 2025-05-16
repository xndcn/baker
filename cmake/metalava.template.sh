#!/bin/bash

metalava=$<TARGET_PROPERTY:metalava,IMPORTED_LOCATION>
classpath=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stubs)
            stubs_dir="$2"
            shift 2
            ;;
        --merge-inclusion-annotations)
            merge_inclusion_annotations="$2"
            shift 2
            ;;
        --src)
            src_file="$2"
            shift 2
            ;;
        --classpath)
            if [ -n "$2" ]; then
                # Split classpath into an array
                IFS=';' read -ra classpath <<< "$2"
                # Join classpath elements with ':' and assign to classpath_arg
                classpath="--classpath "$(IFS=: ; echo "${classpath[*]}")
            fi
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

# metalava may use source file in the same directory which is not expected
# in the src_file. So here we use symbolic links to avoid this issue.

# Make sure metalava directory exists
mkdir -p metalava

# Create new source file to store symbolic link paths
links_file="metalava/source_links.txt"
> "${links_file}"  # Create the file

# Process each line in the source file
while IFS= read -r filepath; do
    if [[ -n "${filepath}" ]]; then
        target_path="${filepath#/}"
        target_dir="metalava/$(dirname "${target_path}")"
        # Create parent directory structure
        mkdir -p "${target_dir}"
        # Create symbolic link
        ln -sf "${filepath}" "metalava/${target_path}"
        echo "metalava/${target_path}" >> "${links_file}"
    fi
done < "${src_file}"

# Use $classpath_arg in your metalava command
${metalava} --java-source 1.8 "@${links_file}" \
    $@ \
    ${classpath} \
    --stubs "${stubs_dir}" \
    --color --quiet --format=v2 \
    --hide UnresolvedImport \
    --merge-inclusion-annotations "${merge_inclusion_annotations}" \
    $<JOIN:$<TARGET_PROPERTY:_droiddoc_options>, > \
    --hide HiddenSuperclass --hide BroadcastBehavior --hide DeprecationMismatch \
    --hide MissingPermission --hide SdkConstant --hide Todo \
    --error-when-new-category Documentation --hide Deprecated \
    --hide IntDef --hide Nullable
