#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

STYLE_FILE="$PROJECT_DIR/www/style.json"
MAPUTNIK_STYLE_FILE="$PROJECT_DIR/www/style-maputnik.json"

echo "Converting style.json to Maputnik-compatible format..."

# Convert pmtiles:// URLs to standard tile URLs
# This uses sed to replace the pmtiles:// protocol with tile server URLs
sed 's|"url": "pmtiles://http://localhost:8080/tiles/\([^"]*\)\.pmtiles"|"tiles": ["http://localhost:8081/\1/{z}/{x}/{y}.mvt"]|g' \
    "$STYLE_FILE" > "$MAPUTNIK_STYLE_FILE"

# Also update glyphs URL to use localhost:8080 (nginx) for fonts
sed -i 's|"glyphs": "http://localhost:8080/|"glyphs": "http://localhost:8080/|g' "$MAPUTNIK_STYLE_FILE"

echo "✓ Created $MAPUTNIK_STYLE_FILE"
echo ""
echo "You can now:"
echo "  1. Open Maputnik: http://localhost:8888"
echo "  2. Load style from URL: http://localhost:8080/style-maputnik.json"
echo "  3. Edit visually in Maputnik"
echo "  4. Export and save as www/style-edited.json"
echo "  5. Run: ./scripts/style-from-maputnik.sh www/style-edited.json"
echo ""
