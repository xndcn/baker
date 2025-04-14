from .blueprint import ast
from .definitions.assignment import Assignment
from .definitions.cc_library import CCLibrary
from .definitions.cc_test_library import CCTestLibrary
from .definitions.cc_library_headers import CCLibraryHeaders
from .definitions.cc_defaults import CCDefaults
from .definitions.cc_binary import CCBinary
from .definitions.cc_test import CCTest
from .definitions.cc_object import CCObject

class CMakeConverter:
    def __init__(self):
        self._handlers = [CCLibraryHeaders, CCLibrary, CCTestLibrary, CCDefaults, CCBinary, CCTest, CCObject]

    def convert(self, project: str, root: ast.Blueprint, subdirectories=None) -> str:
        lines = []

        # list transformations generator expression required for CMake 3.27
        lines.append("cmake_minimum_required(VERSION 3.27)")
        lines.append(f"project({project})")
        lines.append("")

        for definition in root.definitions:
            if isinstance(definition, ast.Assignment):
                lines += Assignment(root, definition).convert_to_cmake()
            else:
                module = definition.name
                for handler in self._handlers:
                    if handler.match(module):
                        lines += handler(root, definition).convert_to_cmake()
                        break
            lines.append("")

        # Add subdirectories if provided
        if subdirectories:
            for subdir in subdirectories:
                lines.append(f"add_subdirectory({subdir})")
            lines.append("")

        return "\n".join(lines)
