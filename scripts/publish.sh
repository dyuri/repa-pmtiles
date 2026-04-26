#!/bin/bash
set -e

# Publish script: copies web assets and tiles to a target directory,
# replacing localhost URLs with the destination URL.
#
# Usage: ./scripts/publish.sh <target-dir> <destination-url>
# Example: ./scripts/publish.sh /var/www/hiking https://maps.example.com

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

TARGET_DIR="$1"
DEST_URL="$2"

if [ -z "$TARGET_DIR" ] || [ -z "$DEST_URL" ]; then
    echo "Usage: $0 <target-dir> <destination-url>"
    echo "Example: $0 /var/www/hiking https://maps.example.com"
    exit 1
fi

# Strip trailing slash from destination URL
DEST_URL="${DEST_URL%/}"

echo "======================================"
echo "Publishing Hungarian Maps"
echo "======================================"
echo ""
echo "Target:      $TARGET_DIR"
echo "Destination: $DEST_URL"
echo ""

# Create target directories
mkdir -p "$TARGET_DIR/tiles"

echo "Copying web assets..."
cp -r "$PROJECT_DIR/www/." "$TARGET_DIR/"

echo "Copying tiles..."
cp "$PROJECT_DIR/tiles/"*.pmtiles "$TARGET_DIR/tiles/"

echo "Substituting URLs (localhost:8080 -> $DEST_URL)..."
find "$TARGET_DIR" -type f \( -name "*.html" -o -name "*.json" \) | while read -r file; do
    sed -i "s|http://localhost:8080|$DEST_URL|g" "$file"
done

echo ""
echo "======================================"
echo "Done!"
echo "======================================"
echo ""
echo "Published files:"
find "$TARGET_DIR" -type f | sort | while read -r f; do
    size=$(du -sh "$f" 2>/dev/null | cut -f1)
    echo "  $size  ${f#$TARGET_DIR/}"
done
echo ""
echo "Maps will be available at:"
echo "  Hiking: $DEST_URL/index.html"
echo "  Bike:   $DEST_URL/bike.html"
echo ""
