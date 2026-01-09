#!/usr/bin/env bash

# Recover maker notes for vivo X300 after they have been processed by other software
#  by reading the original EXIF UserComment in a copy of the original unmodified
#  image files from the stock camera app
# Requires: exiftool, https://exiftool.org/

# Note: on Windows, the input argument must be given as a native Windows path (e.g. E:/Photos) rather than a Cygwin path (e.g. /cygdrive/e/Photos)

INPUT_DIR="collection"

source_dir="$1"

counter=0
no_source_photos=()
empty_maker_note_photos=()

while read -r file; do
	if [ -n "$file" ]; then
		((counter++))

		input_file="$INPUT_DIR/$file"
		input_file_base_name="$(basename "$input_file" .jpg)"
		input_file_parent_dir="$(dirname "$input_file")"

		source_value="$(exiftool -s3 -n -XMP:Source "$input_file")"

		if [ -n "$source_value" ]; then
			source_file_name_with_close_parenthesis="${source_value##*(}"
			source_file="$source_dir/${source_file_name_with_close_parenthesis%)}"

			if [ -n "$source_file" ]; then

				# Manually create temp file path instead of using mktemp in order to support exiftool on Windows
				maker_note_temp_file="$INPUT_DIR/${file%.jpg}.temp"
				while [ -f "$maker_note_temp_file" ]; do
					maker_note_temp_file="$maker_note_temp_file.temp"
				done

				# The EXIF specification requires Unicode text to be encoded in UTF-16 and be prepended with "UNICODE\0"
				# The vivo X300 stock camera does neither of these, instead writing plain UTF-8 directly to the EXIF UserComment
				# This UTF-8 can be read directly as binary (which also serves to preserve line breaks)
				exiftool -b -EXIF:UserComment "$source_file" > "$maker_note_temp_file"

				if [ -s "$maker_note_temp_file" ]; then

					# If user_comment_newline_count is 0, the EXIF UserComment was written by software other than the stock camera, and so should be kept
					# wc --lines only counts lines ending with a newline character; null characters (such as in the Unicode header for UserComment) are treated as any other character

					# Fix maker note of jpg
					user_comment_newline_count="$(exiftool -b -EXIF:UserComment "$input_file" | wc --lines)"
					if [ "$user_comment_newline_count" -eq 0 ]; then
						exiftool -XMP-exif:MakerNote'<='"$maker_note_temp_file" -overwrite_original "$input_file"
					else
						exiftool -EXIF:UserComment= -XMP-exif:MakerNote'<='"$maker_note_temp_file" -overwrite_original "$input_file"
					fi

					# Fix maker note of any XMP sidecar files
					readarray -d '' xmp_files < <( find "$input_file_parent_dir" -maxdepth 1 -type f -name "$input_file_base_name"'.[xX][mM][pP]' -print0 )
					for xmp_file in "${xmp_files[@]}"; do
						user_comment_newline_count="$(exiftool -b -EXIF:UserComment "$xmp_file" | wc --lines)"
						if [ "$user_comment_newline_count" -eq 0 ]; then
							exiftool -XMP-exif:MakerNote'<='"$maker_note_temp_file" -overwrite_original "$xmp_file"
						else
							exiftool -EXIF:UserComment= -XMP-exif:MakerNote'<='"$maker_note_temp_file" -overwrite_original "$xmp_file"
						fi
					done

				else
					empty_maker_note_photos+=("$input_file")
				fi

				rm "$maker_note_temp_file"

			else
				no_source_photos+=("$input_file")
			fi

		else
			no_source_photos+=("$input_file")
		fi

	fi
done <<< "$(find "$INPUT_DIR" -type f -name '*.jpg' -printf '%P\n')"

echo ""
echo "Moved maker notes from EXIF:UserComment to XMP-exif:MakerNote for $((counter - ${#no_source_photos[@]} - ${#empty_maker_note_photos[@]})) out of $counter original *.jpg files"
echo 'Note: warning messages about "Invalid EXIF text encoding for UserComment" are expected and can be ignored'
if [ ${#empty_maker_note_photos[@]} -ne 0 ]; then
	echo "Photos with no source file:"
	for photo in "${no_source_photos[@]}"; do
		echo "$photo"
	done
	echo ""
fi
if [ ${#empty_maker_note_photos[@]} -ne 0 ]; then
	echo "Photos without any maker notes:"
	for photo in "${empty_maker_note_photos[@]}"; do
		echo "$photo"
	done
	echo ""
fi
