#!/bin/bash

# Source and destination folders
SRC="../posters-original size"
DST="posters"

# Create destination folder if needed
mkdir -p "$DST"

# Requires ImageMagick:
# macOS: brew install imagemagick

find "$SRC" -type f \( \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" -o \
    -iname "*.tif" -o \
    -iname "*.tiff" \
\) | while read -r file; do

    # Preserve relative path structure
    rel="${file#$SRC/}"
    outdir="$DST/$(dirname "$rel")"

    mkdir -p "$outdir"

    filename="$(basename "$rel")"
    outfile="$outdir/${filename%.*}.jpg"

    echo "Converting: $file"

    magick "$file" \
        -resize '1200x1200>' \
        -quality 80 \
        -strip \
        "$outfile"

done

echo "Done."
