from .blueprint import ast
from .definitions.assignment import Assignment
from .definitions.cc_modules import CCLibrary, CCTestLibrary, CCLibraryHeaders, CCBinary, CCTest, CCObject
from .definitions.defaults import Defaults
from .definitions.filegroup import FileGroup
from .definitions.genrule import GenRule, GenSrcs
from .definitions.python_binary_host import PythonBinaryHost
from .definitions.aconfig_modules import AConfigDeclarations, CCAConfigLibrary, JavaAConfigLibrary
from .definitions.java_modules import JavaApiLibrary, JavaSdkLibrary, JavaSystemModules, JavaLibrary, DroiddocExportedDir, JavaImport

class CMakeConverter:
    def __init__(self):
        self._handlers = [
            Defaults, FileGroup,
            CCLibraryHeaders, CCLibrary, CCTestLibrary, CCBinary, CCTest, CCObject,
            GenRule, GenSrcs, PythonBinaryHost,
            AConfigDeclarations, CCAConfigLibrary, JavaAConfigLibrary,
            JavaApiLibrary, JavaSdkLibrary, JavaSystemModules, JavaLibrary, DroiddocExportedDir, JavaImport,
        ]

    def convert(self, project: str, root: ast.Blueprint, subdirectories=None) -> str:
        lines = []

        # list transformations generator expression required for CMake 3.27
        # WHOLE_ARCHIVE with multiple entries requires CMake 3.30, may fix by LINK_GROUP:RESCAN
        # See https://gitlab.kitware.com/cmake/cmake/-/issues/25954
        # TRANSITIVE_LINK_PROPERTIES requires CMake 3.30
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
