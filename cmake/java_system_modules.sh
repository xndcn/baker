#!/bin/bash

set -e

javac=${Java_JAVAC_EXECUTABLE}
jar=${Java_JAR_EXECUTABLE}
zipmerge=${ZIPMERGE}

# Find the actual JDK home directory
if [ -L "${javac}" ]; then
    # If javac is a symlink, resolve it
    real_javac=$(readlink -f "${javac}")
    jdk_home=$(dirname "$(dirname "${real_javac}")")
else
    # Try to find JAVA_HOME or use javac's parent directory
    if [ -n "$JAVA_HOME" ]; then
        jdk_home="$JAVA_HOME"
    else
        jdk_home=$(dirname "$(dirname "${javac}")")
    fi
fi
# Get jlink and jmod from the JDK home directory
jlink=${jdk_home}/bin/jlink
jmod=${jdk_home}/bin/jmod

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --jars)
            if [ -n "$2" ]; then
                # Split jars into an array
                IFS=';' read -ra jars <<< "$2"
                # Join classpath elements with ':'
                classpath="$(IFS=: ; echo "${jars[*]}")"
            fi
            shift 2
            ;;
        --outDir)
            outDir="$2"
            shift 2
            ;;
        --moduleVersion)
            moduleVersion="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check required arguments
if [ -z "$classpath" ] || [ -z "$outDir" ] || [ -z "$moduleVersion" ]; then
    echo "Missing required arguments"
    exit 1
fi

workDir=${outDir}/modules/
mkdir -p ${workDir}
# Create module-info.java for java.base
echo "module java.base {" > "${workDir}/module-info.java"
for j in "${jars[@]}"; do zipinfo -1 "$j" ; done \
    | grep -E '/[^/]*\.class$' \
    | sed 's|\(.*\)/[^/]*\.class$|    exports \1;|g' \
    | sed 's|/|.|g' \
    | sort -u >> "${workDir}/module-info.java"
echo "}" >> "${workDir}/module-info.java"

# Compile module-info.java
${javac} --system=none --patch-module=java.base="${classpath}" "${workDir}/module-info.java"
# Create module JAR
${zipmerge} "${workDir}/module.jar" "${jars[@]}"
${jar} --update --file "${workDir}/module.jar" -C "${workDir}" module-info.class

rm -rf ${workDir}/jmod
mkdir -p ${workDir}/jmod

# Create jmod file
${jmod} create --module-version ${moduleVersion} --target-platform LINUX-OTHER --class-path "${workDir}/module.jar" "${workDir}/jmod/java.base.jmod"

systemDir=${outDir}/system/
rm -rf ${systemDir}
# Create system modules with jlink
${jlink} --module-path "${workDir}/jmod" --add-modules java.base --output "${systemDir}" --disable-plugin system-modules
# Copy jrt-fs.jar to system/lib
mkdir -p ${systemDir}/lib/
cp "${jdk_home}/lib/jrt-fs.jar" "${systemDir}/lib/jrt-fs.jar"