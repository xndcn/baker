#!/bin/bash

set -e

metalava=$<TARGET_PROPERTY:metalava,IMPORTED_LOCATION>
source_files="$<TARGET_PROPERTY:INTERFACE_SOURCES>"
classpath="$<GENEX_EVAL:$<JOIN:$<TARGET_PROPERTY:INTERFACE__CLASSPATH_>;$<TARGET_PROPERTY:INTERFACE__LINKED_CLASSPATH_>,;>>"
merge_inclusion_annotations_dirs="$<TARGET_PROPERTY:INTERFACE__ANNOTATION_DIR_>"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stubs)
            stubs_dir="$2"
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

if [ -n "$classpath" ]; then
    # Split classpath into arrays
    IFS=';' read -ra classpath <<< "$classpath"
    # Join classpath elements with ':'
    classpath="$(IFS=: ; echo "${classpath[*]}")"
    classpath="--classpath ${classpath[@]}"
fi

if [ -n "$merge_inclusion_annotations_dirs" ]; then
    # Split merge_inclusion_annotations_dirs into arrays
    IFS=';' read -ra merge_inclusion_annotations_dirs <<< "$merge_inclusion_annotations_dirs"
    # Join directories with ':'
    merge_inclusion_annotations_dirs="$(IFS=: ; echo "${merge_inclusion_annotations_dirs[*]}")"
    merge_inclusion_annotations_dirs="--merge-inclusion-annotations ${merge_inclusion_annotations_dirs}"
fi

# metalava may use source file in the same directory which is not expected
# in the src_file. So here we use symbolic links to avoid this issue.

# Make sure metalava directory exists
link_directory="$<TARGET_PROPERTY:NAME>.metalava"
rm -rf ${link_directory}
mkdir -p ${link_directory}

# Create new response file to store symbolic link paths
links_file="${link_directory}/source_links.rsp"
> "${links_file}"  # Create the file

if [[ -n "${source_files}" ]]; then
    # Split source_files into arrays
    IFS=';' read -ra source_files <<< "$source_files"
    # Process each source file
    for filepath in "${source_files[@]}"; do
        if [[ -n "${filepath}" ]]; then
            target_path="${filepath#/}"
            target_dir="${link_directory}/$(dirname "${target_path}")"
            # Create parent directory structure
            mkdir -p "${target_dir}"
            # Create symbolic link
            ln -sf "${filepath}" "${link_directory}/${target_path}"
            echo "${link_directory}/${target_path}" >> "${links_file}"
        fi
    done
fi

# Use multi-level GENEX_EVAL to handle nested properties
${metalava} \
    "@${links_file}" \
    ${classpath} \
    --stubs "${stubs_dir}" \
    --color --quiet --format=v2 \
    ${merge_inclusion_annotations_dirs} \
    $<JOIN:$<TARGET_PROPERTY:_droiddoc_options>, > \
    $<JOIN:$<TARGET_PROPERTY:_args>, > \
    $<JOIN:$<TARGET_PROPERTY:_flags>, > \
    --hide UnresolvedImport \
    --hide HiddenSuperclass --hide BroadcastBehavior --hide DeprecationMismatch \
    --hide MissingPermission --hide SdkConstant --hide Todo \
    --error-when-new-category Documentation --hide Deprecated \
    --hide IntDef --hide Nullable

# TODO: add api checking