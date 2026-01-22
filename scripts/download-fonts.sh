#!/bin/bash
set -e

# Script to download pre-built font glyphs for MapLibre
# Usage: ./scripts/download-fonts.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FONTS_DIR="$PROJECT_DIR/www/fonts"

echo "======================================"
echo "Downloading MapLibre Fonts"
echo "======================================"
echo ""

# Create fonts directory
mkdir -p "$FONTS_DIR"

echo "Downloading pre-built font glyphs from OpenFreeMap..."
echo "This includes Noto Sans Regular and Bold"
echo ""

# Download pre-built PBF fonts from OpenFreeMap
# These are the exact same format MapLibre needs
FONT_BASE_URL="https://tiles.openfreemap.org/fonts"

# Font stacks we need
FONTS=("Noto Sans Regular" "Noto Sans Bold")

for font in "${FONTS[@]}"; do
    echo "Downloading ${font}..."
    font_dir="$FONTS_DIR/${font}"
    mkdir -p "$font_dir"

    # Download common Unicode ranges (0-65535, step 256)
    # We'll download the most common ranges to save space
    # Extended to 10240 to include geometric shapes used for trail symbols (▲, ●, ■, etc.)
    for start in {0..9984..256}; do
        end=$((start + 255))
        url_font=$(echo "$font" | sed 's/ /%20/g')

        wget -q -O "$font_dir/${start}-${end}.pbf" \
            "$FONT_BASE_URL/${url_font}/${start}-${end}.pbf" 2>/dev/null || true
    done

    # Remove any empty/failed downloads
    find "$font_dir" -size 0 -delete
done

echo ""
echo "======================================"
echo "Font download complete!"
echo "======================================"
echo ""
echo "Downloaded fonts to: $FONTS_DIR"
echo ""
echo "Font files installed:"
find "$FONTS_DIR" -name "*.pbf" | wc -l
echo ""
echo "Fonts are now ready to use!"
