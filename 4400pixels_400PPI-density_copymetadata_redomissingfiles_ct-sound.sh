#!/bin/bash

output_dir="4400 pixels"
mkdir -p "$output_dir"

# Get the list of TIFF files
tiff_files=(*.tiff *.tif)

# Check if there are any TIFF files
if [ ${#tiff_files[@]} -eq 0 ]; then
  echo "No TIFF files found in the directory."
  osascript -e 'tell app "System Events" to display dialog "No TIFF files found in the directory." buttons {"OK"} with title "Script Notification"'
  exit 1
fi

# Extract the base names of the first and last files (if there are any)
if [ ${#tiff_files[@]} -gt 0 ]; then
  first_file=$(basename "${tiff_files[0]}" .tiff)
  last_file=$(basename "${tiff_files[-1]}" .tiff)
fi

# Get the name of the root folder
root_folder=$(basename "$PWD")

# Create a unique error log filename
error_log="error_report_${root_folder}_${first_file}-${last_file}.log"
> "$error_log"

# Function to check if a file is missing or corrupt
check_file() {
  local input_file="$1"
  local output_file="$2"

  if [ ! -f "$output_file" ]; then
    return 1
  fi

  # Check if the file is corrupt
  if ! magick identify "$output_file" > /dev/null 2>&1; then
    return 1
  fi

  return 0
}

convert_file() {
  local input_file="$1"
  local output_file="$2"

  magick "$input_file" -resize "x4400" -density 400 -compress LZW "$output_file" 2>&1 | grep -v "Wrong data type 3 for \"PixelXDimension\"" | grep -v "Wrong data type 3 for \"PixelYDimension\"" >> "$error_log"
  exiftool -TagsFromFile "$input_file" -all:all -overwrite_original "$output_file" 2>&1 | grep -v "Wrong data type 3 for \"PixelXDimension\"" | grep -v "Wrong data type 3 for \"PixelYDimension\"" >> "$error_log"
}

# Loop through TIFF files
for f in "${tiff_files[@]}"; do
  input_file="$f"
  output_file="$output_dir/$f"

  if ! check_file "$input_file" "$output_file"; then
    convert_file "$input_file" "$output_file"
  fi

  # Validate the conversion
  if ! check_file "$input_file" "$output_file"; then
    echo "Error converting $input_file" >> "$error_log"
  else
    echo "Successfully converted $input_file" >> "$error_log"
  fi

  # Add a line break between files
  echo "" >> "$error_log"
done

# Re-check and convert any missed files
for f in "${tiff_files[@]}"; do
  input_file="$f"
  output_file="$output_dir/$f"

  if ! check_file "$input_file" "$output_file"; then
    convert_file "$input_file" "$output_file"
  fi

  # Validate the conversion again
  if ! check_file "$input_file" "$output_file"; then
    echo "Error converting $input_file on re-check" >> "$error_log"
  else
    echo "Successfully converted $input_file on re-check" >> "$error_log"
  fi

  # Add a line break between files
  echo "" >> "$error_log"
done

# Check if the number of files in the output directory matches the original directory
original_count=$(ls *.tiff *.tif 2>/dev/null | wc -l)
output_count=$(ls "$output_dir"/*.tiff "$output_dir"/*.tif 2>/dev/null | wc -l)

if [ "$original_count" -ne "$output_count" ]; then
  echo "Mismatch in file count: Original ($original_count), Output ($output_count)" >> "$error_log"
else
  echo "File count matches: $original_count files" >> "$error_log"
fi

echo "All done! Check $error_log for more information"
osascript -e 'tell app "System Events" to display dialog "Image processing is complete! All done!" buttons {"OK"} with title "Script Notification" giving up after 1'
open .

# Play custom sound
afplay ~/Documents/ChronoTriggerFanfare3.mp3
