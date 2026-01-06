#!/usr/bin/env bash

# Requires:
# - exiftool, https://exiftool.org/
# - motionminer from PyPI, patched to extract standalone photos, as in latest commit at https://github.com/yushiyangk/MotionMiner/tree/photo

INPUT_DIR="Photos-source/x300"
OUTPUT_VIDEO_DIR="Photos-source/x300_livephoto_video"
OUTPUT_PHOTO_DIR="Photos-source/x300_livephoto_photo"
LIVE_PHOTO_KEYWORD="Live Photo"
LIVE_PHOTO_HIERARCHICAL_KEYWORD="__SOURCES|_phones|vivo X300|Panopticon|stock camera|Live Photo"

motion_photos=()
counter=0

while read -r file; do
	((counter++))

	input_file="$INPUT_DIR/$file"
	input_file_base_name="$(basename "$input_file" .jpg)"
	input_file_parent_dir="$(dirname "$input_file")"
	output_video_file="$OUTPUT_VIDEO_DIR/${file%.jpg}_video.mp4"
	output_photo_file="$OUTPUT_PHOTO_DIR/${file%.jpg}_photo.jpg"
	mkdir -p "$(dirname "$output_video_file")"
	mkdir -p "$(dirname "$output_photo_file")"

	if motionminer "Photos-source/x300/$file" -o "$output_video_file" -p "$output_photo_file"; then
		# Write keyword to original image
		exiftool \
			-IPTC:Keywords-="$LIVE_PHOTO_KEYWORD" -IPTC:Keywords+="$LIVE_PHOTO_KEYWORD" \
			-XMP-dc:Subject-="$LIVE_PHOTO_KEYWORD" -XMP-dc:Subject+="$LIVE_PHOTO_KEYWORD" \
			-XMP-lr:WeightedFlatSubject-="$LIVE_PHOTO_KEYWORD" -XMP-lr:WeightedFlatSubject+="$LIVE_PHOTO_KEYWORD" \
			-XMP-lr:HierarchicalSubject-="$LIVE_PHOTO_HIERARCHICAL_KEYWORD" -XMP-lr:HierarchicalSubject+="$LIVE_PHOTO_HIERARCHICAL_KEYWORD" \
			-IPTCDigest=new -overwrite_original "$input_file"

		# Write keyword to any XMP sidecar files
		readarray -d '' XMP_FILES < <( find "$input_file_parent_dir" -type f -name "$input_file_base_name"'.[xX][mM][pP]' -print0 )
		for xmp_file in "${XMP_FILES[@]}"; do
			exiftool \
				-IPTC:Keywords-="$LIVE_PHOTO_KEYWORD" -IPTC:Keywords+="$LIVE_PHOTO_KEYWORD" \
				-XMP-dc:Subject-="$LIVE_PHOTO_KEYWORD" -XMP-dc:Subject+="$LIVE_PHOTO_KEYWORD" \
				-XMP-lr:WeightedFlatSubject-="$LIVE_PHOTO_KEYWORD" -XMP-lr:WeightedFlatSubject+="$LIVE_PHOTO_KEYWORD" \
				-XMP-lr:HierarchicalSubject-="$LIVE_PHOTO_HIERARCHICAL_KEYWORD" -XMP-lr:HierarchicalSubject+="$LIVE_PHOTO_HIERARCHICAL_KEYWORD" \
				-IPTCDigest=new -overwrite_original "$xmp_file"
		done

		# Write keyword to extracted photo and remove motion photo metadata (except VCamera)
		exiftool \
			-IPTC:Keywords-="$LIVE_PHOTO_KEYWORD" -IPTC:Keywords+="$LIVE_PHOTO_KEYWORD" \
			-XMP-dc:Subject-="$LIVE_PHOTO_KEYWORD" -XMP-dc:Subject+="$LIVE_PHOTO_KEYWORD" \
			-XMP-lr:WeightedFlatSubject-="$LIVE_PHOTO_KEYWORD" -XMP-lr:WeightedFlatSubject+="$LIVE_PHOTO_KEYWORD" \
			-XMP-lr:HierarchicalSubject-="$LIVE_PHOTO_HIERARCHICAL_KEYWORD" -XMP-lr:HierarchicalSubject+="$LIVE_PHOTO_HIERARCHICAL_KEYWORD" \
			-XMP-Gcamera:MotionPhoto=0 \
			-XMP-GContainer:DirectoryItemLength= \
			-XMP-GContainer:DirectoryItemMime= \
			-XMP-GContainer:DirectoryItemPadding= \
			-XMP-GContainer:DirectoryItemSemantic= \
			-IPTCDigest=new -overwrite_original "$output_photo_file"

		motion_photos+=("$input_file")
	fi
done <<< "$(find "$INPUT_DIR" -type f -name *.jpg -printf '%P\n')"

echo ""
if [ ${#motion_photos[@]} -ne 0 ]; then
	echo "Found and extracted ${#motion_photos[@]} motion photos out of $counter original *.jpg files:"
	for photo in "${motion_photos[@]}"; do
		echo "$photo"
	done
	echo ""
	echo "Extracted to $OUTPUT_VIDEO_DIR and $OUTPUT_PHOTO_DIR"
else
	echo "Found and extracted 0 motion photos out of $counter original *.jpg files"
fi
