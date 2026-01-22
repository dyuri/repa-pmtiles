#!/bin/bash
set -e

MKGMAP_JAR="/opt/garmin/mkgmap/mkgmap.jar"
SPLITTER_JAR="/opt/garmin/splitter/splitter.jar"

# Default Java memory settings
JAVA_OPTS="${JAVA_OPTS:--Xmx8G}"

# Detect which tool to run
case "$1" in
    mkgmap)
        shift
        exec java $JAVA_OPTS -jar "$MKGMAP_JAR" "$@"
        ;;
    splitter)
        shift
        exec java $JAVA_OPTS -jar "$SPLITTER_JAR" "$@"
        ;;
    bash)
        exec /bin/bash
        ;;
    *)
        echo "Garmin Map Builder"
        echo ""
        echo "Usage:"
        echo "  mkgmap [options]     - Run mkgmap"
        echo "  splitter [options]   - Run splitter"
        echo "  bash                 - Open shell"
        echo ""
        echo "Example:"
        echo "  docker run garmin-builder mkgmap --help"
        echo "  docker run garmin-builder splitter --help"
        exit 1
        ;;
esac
