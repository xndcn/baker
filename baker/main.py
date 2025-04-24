import sys
import os
import argparse
from .blueprint.parser import Parser
from .cmake_converter import CMakeConverter

def find_blueprint_files(root_dir):
    blueprint_files = []
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename == 'Android.bp':
                blueprint_files.append(os.path.join(dirpath, filename))
    return blueprint_files

def process_blueprint_file(blueprint_path, output_path=None, subdirectories=None):
    # Get project name from directory name
    project = os.path.basename(os.path.dirname(os.path.abspath(blueprint_path)))

    parser = Parser()
    ast = parser.parse_file(blueprint_path)

    converter = CMakeConverter()
    cmake = converter.convert(project, ast, subdirectories)

    if not output_path:
        output_path = os.path.join(os.path.dirname(blueprint_path), 'CMakeLists.txt')
    else:
        # Ensure output path exists
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)

    with open(output_path, 'w') as f:
        f.write(cmake)

    return output_path

def main():
    parser = argparse.ArgumentParser(description='Convert Android.bp to CMakeLists.txt')
    parser.add_argument('blueprint', metavar='Android.bp', help='Path to the Android.bp file or directory')
    parser.add_argument('--recursive', '-r', action='store_true', help='Recursively convert Android.bp files in subdirectories')
    parser.add_argument('--output', '-o', help='Specify output file path (default: CMakeLists.txt in the same directory as Android.bp)')
    args = parser.parse_args()

    blueprint = args.blueprint
    recursive = args.recursive
    output_file = args.output

    # Determine files to process
    blueprint_files = []
    root_dir = os.path.abspath(blueprint if os.path.isdir(blueprint) else os.path.dirname(blueprint))

    if not recursive:
        blueprint_files = [os.path.join(blueprint, 'Android.bp') if os.path.isdir(blueprint) else blueprint]
    else:
        # Find all Android.bp files recursively
        blueprint_files = find_blueprint_files(root_dir)

    if not blueprint_files:
        print(f"No Android.bp files found at {blueprint}")
        return 1

    subdirectories_map = {}
    for bp_file in blueprint_files:
        dir_path = os.path.dirname(os.path.relpath(bp_file, root_dir))
        if dir_path != "":
            parent = os.path.dirname(dir_path)
            # When the parent directory do not contain Android.bp, go up to the next directory
            while parent != "" and not os.path.join(root_dir, os.path.join(parent, 'Android.bp')) in blueprint_files:
                parent = os.path.dirname(parent)
            subdirectories_map.setdefault(parent, []).append(os.path.relpath(dir_path, parent))

    # Process all identified files
    processed_files = []
    for bp_file in blueprint_files:
        # If output file is specified and we only have one file to process, use it
        output_path = output_file if output_file and len(blueprint_files) == 1 else None
        dir_path = os.path.dirname(os.path.relpath(bp_file, root_dir))
        subdirectories = subdirectories_map.get(dir_path, [])
        output_file_path = process_blueprint_file(bp_file, output_path=output_path, subdirectories=subdirectories)
        processed_files.append((bp_file, output_file_path))

    # Print summary
    print(f"Processed {len(processed_files)} Android.bp files:")
    for bp_file, out_file in processed_files:
        print(f"  {bp_file} -> {out_file}")

    return 0

if __name__ == "__main__":
    sys.exit(main())
