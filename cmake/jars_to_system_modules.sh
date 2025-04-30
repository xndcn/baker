#!/bin/bash

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --jars)
        JARS="$2"
        shift 2
        ;;
        --outDir)
        OUT_DIR="$2"
        shift 2
        ;;
        --workDir)
        WORK_DIR="$2"
        shift 2
        ;;
        *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Check required arguments
if [ -z "$JARS" ] || [ -z "$OUT_DIR" ] || [ -z "$WORK_DIR" ]; then
    echo "Missing required arguments"
    exit 1
fi

# Clean output directories
rm -rf "${OUT_DIR}" "${WORK_DIR}"
mkdir -p "${WORK_DIR}/jmod"

# Create module-info.java for java.base
cat > "${WORK_DIR}/module-info.java" << EOF
module java.base {
    exports java.lang;
    exports java.io;
    exports java.util;
}
EOF

# Compile module-info.java
javac --system=none --patch-module=java.base="${JARS}" "${WORK_DIR}/module-info.java"

# Create module JAR
jar -cf "${WORK_DIR}/classes.jar" -C "${WORK_DIR}" module-info.class
jar -cf "${WORK_DIR}/module.jar" -C "${WORK_DIR}" module-info.class "@${JARS}"

# Create jmod file
jmod create --module-version 11 --target-platform LINUX \
  --class-path "${WORK_DIR}/module.jar" "${WORK_DIR}/jmod/java.base.jmod"

# Create system modules with jlink
jlink --module-path "${WORK_DIR}/jmod" --add-modules java.base --output "${OUT_DIR}" \
  --disable-plugin system-modules

# Copy jrt-fs.jar
cp "$(dirname "$(dirname "$(which java)")")"/lib/jrt-fs.jar "${OUT_DIR}/lib/"

echo "System modules generated successfully at ${OUT_DIR}"