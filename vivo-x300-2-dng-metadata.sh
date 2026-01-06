#!/usr/bin/env bash

# Requires: exiftool, https://exiftool.org/

INPUT_DIR="Photos-source/x300"

counter=0
no_jpeg_raw_photos=()

while read -r file; do
	if [ -n "$file" ]; then
		((counter++))

		input_file="$INPUT_DIR/$file"
		input_file_base_name="$(basename "$input_file" .dng)"
		input_file_parent_dir="$(dirname "$input_file")"
		jpeg_file="$input_file_parent_dir/$input_file_base_name.jpg"

		if [ -f "$jpeg_file" ]; then
			# Copy metadata from JPEG to XMP sidecar
			exiftool -tagsFromFile "$jpeg_file" -overwrite_original "$input_file"
		fi

	fi
done <<< "$(find "$INPUT_DIR" -type f -name '*.dng' -printf '%P\n')"

echo ""
echo "Copied metadata from JPEG for $((counter - ${#no_jpeg_raw_photos[@]})) out of $counter original *.dng files"
if [ ${#no_jpeg_raw_photos[@]} -ne 0 ]; then
	echo "DNG files without an accompanying JPEG to read metadata from:"
	for photo in "${no_jpeg_raw_photos[@]}"; do
		echo "$photo"
	done
	echo ""
fi
