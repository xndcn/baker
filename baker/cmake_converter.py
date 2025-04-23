from .blueprint import ast
from .definitions.assignment import Assignment
from .definitions.cc_library import CCLibrary
from .definitions.cc_test_library import CCTestLibrary
from .definitions.cc_library_headers import CCLibraryHeaders
from .definitions.defaults import Defaults
from .definitions.cc_binary import CCBinary
from .definitions.cc_test import CCTest
from .definitions.cc_object import CCObject
from .definitions.filegroup import FileGroup
from .definitions.genrule import GenRule
from .definitions.gensrcs import GenSrcs
from .definitions.python_binary_host import PythonBinaryHost
from .definitions.aconfig_declarations import AConfigDeclarations
from .definitions.cc_aconfig_library import CCAConfigLibrary

class CMakeConverter:
    def __init__(self):
        self._handlers = [
            Defaults, FileGroup,
            CCLibraryHeaders, CCLibrary, CCTestLibrary, CCBinary, CCTest, CCObject,
            GenRule, GenSrcs, PythonBinaryHost,
            AConfigDeclarations, CCAConfigLibrary
        ]

    def convert(self, project: str, root: ast.Blueprint, subdirectories=None) -> str:
        lines = []

        # list transformations generator expression required for CMake 3.27
        # WHOLE_ARCHIVE with multiple entries requires CMake 3.30, may fix by LINK_GROUP:RESCAN
        # See https://gitlab.kitware.com/cmake/cmake/-/issues/25954
        lines.append("cmake_minimum_required(VERSION 3.30)")
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
