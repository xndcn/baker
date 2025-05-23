#!/bin/bash

set -e

metalava=$<TARGET_PROPERTY:metalava,IMPORTED_LOCATION>
classpath=""
merge_inclusion_annotations=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stubs)
            stubs_dir="$2"
            shift 2
            ;;
        --merge-inclusion-annotations)
            if [[ -n "$2" ]]; then
                merge_inclusion_annotations="--merge-inclusion-annotations $2"
            fi
            shift 2
            ;;
        --src)
            src_file="$2"
            shift 2
            ;;
        --classpath)
            if [[ -n "$2" ]]; then
                classpath="--classpath $2"
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
rm -rf metalava
mkdir -p metalava

# Create new source file to store symbolic link paths
links_file="metalava/source_links.txt"
> "${links_file}"  # Create the file

if [[ -f "${src_file}" ]]; then
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
fi

${metalava} "@${links_file}" \
    $@ \
    ${classpath} \
    --stubs "${stubs_dir}" \
    --color --quiet --format=v2 \
    --hide UnresolvedImport \
    ${merge_inclusion_annotations} \
    $<JOIN:$<TARGET_PROPERTY:_droiddoc_options>, > \
    $<JOIN:$<TARGET_PROPERTY:_args>, > \
    $<JOIN:$<TARGET_PROPERTY:_flags>, > \
    --hide HiddenSuperclass --hide BroadcastBehavior --hide DeprecationMismatch \
    --hide MissingPermission --hide SdkConstant --hide Todo \
    --error-when-new-category Documentation --hide Deprecated \
    --hide IntDef --hide Nullable
