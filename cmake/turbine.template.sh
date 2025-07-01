#!/bin/bash

set -e

java=${Java_JAVA_EXECUTABLE}
turbine="${java} -cp $<TARGET_PROPERTY:turbine,IMPORTED_LOCATION> com.google.turbine.main.Main"

sources=""
output=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sources)
            sources="$2"
            shift 2
            ;;
        --output)
            output="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$output" ]; then
    echo "Error: --output is required"
    exit 1
fi
if [ -z "$sources" ]; then
    echo "Error: --sources is required"
    exit 1
fi

bootclasspath="$<TARGET_PROPERTY:INTERFACE__LINKED_CLASSPATH_>"
if [ "$bootclasspath" != "" ]; then
    IFS=';' read -ra bootclasspath <<< "$bootclasspath"
    # turbine bootclasspath is separated by space
    bootclasspath="--bootclasspath ${bootclasspath[*]}"
fi

classpath="$<TARGET_PROPERTY:INTERFACE__CLASSPATH_>"
if [ "$classpath" != "" ]; then
    IFS=';' read -ra classpath <<< "$classpath"
    # turbine classpath is separated by space
    classpath="--classpath ${classpath[*]}"
fi

${turbine} \
    --output "${output}" \
    --sources "${sources}" \
    ${bootclasspath} \
    ${classpath}