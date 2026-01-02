#!/bin/bash

# Usage: ./hardlinker.sh <Source Folder> <Base Destination Folder>
# Example: ./hardlinker.sh /downloads/MyMovie /media/Movies/

INPUT_SOURCE="$1"
INPUT_DEST_BASE="$2"

# 1. Check if inputs exist
if [ -z "$INPUT_SOURCE" ] || [ -z "$INPUT_DEST_BASE" ]; then
    echo "Usage: $0 <source_folder> <base_destination_folder>"
    exit 1
fi

# 2. Get absolute paths to ensure safety
SOURCE_FULL_PATH=$(realpath "$INPUT_SOURCE")
DEST_BASE_FULL_PATH=$(realpath "$INPUT_DEST_BASE")

# 3. Extract the folder name from the source (e.g., gets "MyMovie" from "/downloads/MyMovie")
SOURCE_FOLDER_NAME=$(basename "$SOURCE_FULL_PATH")

# 4. Define the final destination path
FINAL_DEST_DIR="$DEST_BASE_FULL_PATH/$SOURCE_FOLDER_NAME"

echo "---------------------------------------------------"
echo "Source:      $SOURCE_FULL_PATH"
echo "Destination: $FINAL_DEST_DIR"
echo "---------------------------------------------------"

# 5. Enter source directory
cd "$SOURCE_FULL_PATH" || { echo "Source directory not found"; exit 1; }

# 6. Find .mkv files, create directory structure in destination, and link
#    We use -print0 and read -d '' to handle filenames with spaces correctly.
find . -type f -name "*.mkv" -print0 | while IFS= read -r -d '' file; do
    
    # Strip the leading "./" from find output
    clean_file="${file#./}"
    
    # Get the directory structure of the file (e.g., "Season 1")
    dir_structure=$(dirname "$clean_file")
    
    # Create the directory tree in the destination
    mkdir -p "$FINAL_DEST_DIR/$dir_structure"
    
    # Create the hardlink
    # If the link already exists, we skip it to avoid errors (or use ln -f to overwrite)
    if [ ! -e "$FINAL_DEST_DIR/$clean_file" ]; then
        ln "$SOURCE_FULL_PATH/$clean_file" "$FINAL_DEST_DIR/$clean_file"
        echo "Linked: $clean_file"
    else
        echo "Skipped (Exists): $clean_file"
    fi
done

echo "---------------------------------------------------"
echo "Operation Complete."
