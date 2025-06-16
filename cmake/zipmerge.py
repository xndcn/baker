#!/usr/bin/env python3

import sys
import zipfile
import os

def zipmerge(output_filename, input_filenames):
    """Merge multiple zip files into one output zip file."""
    added_files = set()
    
    with zipfile.ZipFile(output_filename, 'w', zipfile.ZIP_DEFLATED) as output_zip:
        for input_filename in input_filenames:
            if not os.path.exists(input_filename):
                print(f"Warning: {input_filename} does not exist, skipping...")
                continue

            with zipfile.ZipFile(input_filename, 'r') as input_zip:
                for file_info in input_zip.infolist():
                    filename = file_info.filename
                    if filename in added_files:
                        print(f"Warning: Duplicate name '{filename}' found, skipping...")
                        continue

                    added_files.add(filename)
                    # Stream file data from input zip
                    with input_zip.open(file_info.filename) as file_stream:
                        # Write to output zip in chunks
                        output_zip.writestr(file_info, file_stream.read())

def main():
    if len(sys.argv) < 3:
        print("Usage: zipmerge.py <output.zip> <input1.zip> [input2.zip] ...")
        sys.exit(1)

    output_filename = sys.argv[1]
    input_filenames = sys.argv[2:]

    try:
        zipmerge(output_filename, input_filenames)
        print(f"Successfully merged {len(input_filenames)} zip files into {output_filename}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()