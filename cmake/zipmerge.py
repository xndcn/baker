#!/usr/bin/env python3

import sys
import zipfile
import os
import argparse

def zipmerge(output_filename, input_filenames, append_mode=False):
    """Merge multiple zip files into one output zip file."""
    added_files = set()

    # Use append mode if requested and file exists, otherwise write mode
    mode = 'a' if append_mode and os.path.exists(output_filename) else 'w'
    with zipfile.ZipFile(output_filename, mode, zipfile.ZIP_DEFLATED) as output_zip:
        # If appending, track existing files to avoid duplicates
        if mode == 'a':
            for existing_file in output_zip.namelist():
                added_files.add(existing_file)

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
    parser = argparse.ArgumentParser(description='Merge multiple zip files into one output zip file.')
    parser.add_argument('output', help='Output zip file')
    parser.add_argument('inputs', nargs='*', help='Input zip files')
    parser.add_argument('-a', '--append', action='store_true',
                       help='Append to existing output zip file instead of overwriting')
    args = parser.parse_args()

    try:
        zipmerge(args.output, args.inputs, args.append)
        print(f"Successfully merged {len(args.inputs)} zip files into {args.output}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()