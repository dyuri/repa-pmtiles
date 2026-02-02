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

# Download pre-built PBF fonts
# We use multiple sources and keep the larger file to ensure maximum character coverage
SOURCES=(
    "https://tiles.openfreemap.org/fonts"
    "https://protomaps.github.io/basemaps-assets/fonts"
)

# Font stacks we need
FONTS=("Noto Sans Regular" "Noto Sans Bold")

for font in "${FONTS[@]}"; do
    echo "Downloading ${font}..."
    font_dir="$FONTS_DIR/${font}"
    mkdir -p "$font_dir"

    # Download common Unicode ranges (0-65535, step 256)
    # Extended to 10240 to include geometric shapes used for trail symbols (▲, ●, ■, etc.)
    for start in {0..9984..256}; do
        end=$((start + 255))
        filename="${start}-${end}.pbf"
        
        # Try each source and keep the largest file
        for source in "${SOURCES[@]}"; do
            url_font=$(echo "$font" | sed 's/ /%20/g')
            temp_file="/tmp/${font}_${filename}"
            
            if wget -q -O "$temp_file" "$source/$url_font/$filename" 2>/dev/null; then
                if [ ! -f "$font_dir/$filename" ] || [ $(stat -c%s "$temp_file") -gt $(stat -c%s "$font_dir/$filename") ]; then
                    mv "$temp_file" "$font_dir/$filename"
                else
                    rm "$temp_file"
                fi
            fi
        done
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
