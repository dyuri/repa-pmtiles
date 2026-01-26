#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

EDITED_STYLE="${1:-$PROJECT_DIR/www/style-edited.json}"
OUTPUT_STYLE="$PROJECT_DIR/www/style.json"
BACKUP_STYLE="$PROJECT_DIR/www/style.json.backup"

if [ ! -f "$EDITED_STYLE" ]; then
    echo "Error: Edited style file not found: $EDITED_STYLE"
    echo ""
    echo "Usage: $0 [path-to-edited-style.json]"
    echo ""
    echo "Example:"
    echo "  $0 www/style-edited.json"
    echo ""
    exit 1
fi

echo "Converting Maputnik style back to pmtiles:// format..."

# Backup existing style
if [ -f "$OUTPUT_STYLE" ]; then
    cp "$OUTPUT_STYLE" "$BACKUP_STYLE"
    echo "✓ Backed up existing style to $BACKUP_STYLE"
fi

# Convert tile URLs back to pmtiles:// protocol
# Replace tiles array with url using pmtiles:// protocol
sed 's|"tiles": \["http://localhost:8081/\([^/]*\)/{z}/{x}/{y}\.mvt"\]|"url": "pmtiles://http://localhost:8080/tiles/\1.pmtiles"|g' \
    "$EDITED_STYLE" > "$OUTPUT_STYLE"

echo "✓ Converted style saved to $OUTPUT_STYLE"
echo ""
echo "Next steps:"
echo "  1. Hard refresh your browser (Ctrl+Shift+R)"
echo "  2. Check that your map loads correctly"
echo "  3. If something is wrong, restore backup:"
echo "     cp $BACKUP_STYLE $OUTPUT_STYLE"
echo ""
