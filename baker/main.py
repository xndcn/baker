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

def get_subdirectories_with_blueprint(directory):
    subdirs = []
    for item in os.listdir(directory):
        item_path = os.path.join(directory, item)
        if os.path.isdir(item_path) and os.path.exists(os.path.join(item_path, 'Android.bp')):
            subdirs.append(item)
    return subdirs

def process_blueprint_file(blueprint_path, output_path=None, recursive=False):
    # Get project name from directory name
    project = os.path.basename(os.path.dirname(os.path.abspath(blueprint_path)))

    parser = Parser()
    ast = parser.parse_file(blueprint_path)

    # Find subdirectories with Android.bp files if recursive mode is enabled
    subdirectories = None
    if recursive:
        dir_path = os.path.dirname(blueprint_path)
        subdirectories = get_subdirectories_with_blueprint(dir_path)

    converter = CMakeConverter()
    cmake = converter.convert(project, ast, subdirectories)

    if not output_path:
        output_path = os.path.join(os.path.dirname(blueprint_path), 'CMakeLists.txt')

    with open(output_path, 'w') as f:
        f.write(cmake)

    return output_path

def main():
    parser = argparse.ArgumentParser(description='Convert Android.bp to CMakeLists.txt')
    parser.add_argument('blueprint', metavar='Android.bp', help='Path to the Android.bp file or directory')
    parser.add_argument('--recursive', '-r', action='store_true', help='Recursively convert Android.bp files in subdirectories')
    args = parser.parse_args()

    blueprint = args.blueprint
    recursive = args.recursive

    # Determine files to process
    blueprint_files = []

    if not recursive:
        blueprint_files = [os.path.join(blueprint, 'Android.bp') if os.path.isdir(blueprint) else blueprint]
    else:
        # Find all Android.bp files recursively
        search_root = blueprint if os.path.isdir(blueprint) else os.path.dirname(os.path.abspath(blueprint))
        blueprint_files = find_blueprint_files(search_root)

    if not blueprint_files:
        print(f"No Android.bp files found at {blueprint}")
        return 1

    # Process all identified files
    processed_files = []
    for bp_file in blueprint_files:
        output_file = process_blueprint_file(bp_file, recursive=recursive)
        processed_files.append((bp_file, output_file))

    # Print summary
    print(f"Processed {len(processed_files)} Android.bp files:")
    for bp_file, out_file in processed_files:
        print(f"  {bp_file} -> {out_file}")

    return 0

if __name__ == "__main__":
    sys.exit(main())
