#!/usr/bin/env bash

# Requires: exiftool, https://exiftool.org/

INPUT_DIR="Photos-source/x300"

counter=0
empty_maker_note_photos=()

while read -r file; do
	((counter++))

	input_file="$INPUT_DIR/$file"
	input_file_base_name="$(basename "$input_file" .jpg)"
	input_file_parent_dir="$(dirname "$input_file")"

	# The EXIF specification requires Unicode text to be encoded in UTF-16 and be prepended with "UNICODE\0"
	# The vivo X300 stock camera does neither of these, instead writing plain UTF-8 directly to the EXIF UserComment
	# This UTF-8 can be read directly as binary (which also serves to preserve line breaks)
	maker_note="$(exiftool -b -EXIF:UserComment "$input_file")"

	if [ -n "$maker_note" ]; then

		# Fix maker note of jpg
		exiftool -EXIF:UserComment= -XMP-exif:MakerNote="$maker_note" -overwrite_original "$input_file"

		# Fix maker note of any XMP sidecar files
		readarray -d '' XMP_FILES < <( find "$input_file_parent_dir" -type f -name "$input_file_base_name"'.[xX][mM][pP]' -print0 )
		for xmp_file in "${XMP_FILES[@]}"; do
			exiftool -EXIF:UserComment= -XMP-exif:MakerNote="$maker_note" -overwrite_original "$xmp_file"
		done

	else
		empty_maker_note_photos+=("$input_file")
	fi

done <<< "$(find "$INPUT_DIR" -type f -name '*.jpg' -printf '%P\n')"

echo ""
echo "Moved maker notes from EXIF:UserComment to XMP-exif:MakerNote for $((counter - ${#empty_maker_note_photos[@]})) out of $counter original *.jpg files"
echo 'Note: warning messages about "Invalid EXIF text encoding for UserComment" are expected and can be ignored'
if [ ${#empty_maker_note_photos[@]} -ne 0 ]; then
	echo "Photos without any maker notes:"
	for photo in "${empty_maker_note_photos[@]}"; do
		echo "$photo"
	done
	echo ""
fi
