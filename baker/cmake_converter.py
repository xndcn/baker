from .blueprint import ast
from .definitions.assignment import Assigment
from .definitions.cc_library import CCLibrary
from .definitions.cc_library_headers import CCLibraryHeaders
from .definitions.cc_defaults import CCDefaults
from .definitions.cc_binary import CCBinary
from .definitions.cc_test import CCTest

class CMakeConverter:
    def __init__(self):
        self._handlers = [CCLibraryHeaders, CCLibrary, CCDefaults, CCBinary, CCTest]

    def convert(self, project: str, root: ast.Blueprint, subdirectories=None) -> str:
        lines = []

        # list transformations generator expression required for CMake 3.27
        lines.append("cmake_minimum_required(VERSION 3.27)")
        lines.append(f"project({project})")
        lines.append("")

        # Collect all module definitions and their handlers
        modules = {}

        # Process all assignments first
        for definition in root.definitions:
            if isinstance(definition, ast.Assignment):
                lines += Assigment(root, definition).convert_to_cmake()
                lines.append("")
            else:
                for handler in self._handlers:
                    if handler.match(definition.name):
                        module = handler(root, definition)
                        modules[module.name()] = module
                        break

        processed_modules = set()
        # Process modules in dependency order
        while modules:
            processed_any = False

            for name, module in list(modules.items()):
                dependencies = module.dependencies()
                # If no dependencies or all dependencies already processed, we can process this module
                if not dependencies or all(dep in processed_modules for dep in dependencies):
                    lines += module.convert_to_cmake()
                    lines.append("")
                    processed_modules.add(name)
                    del modules[name]
                    processed_any = True

            # If we didn't process any modules in this iteration but there are still modules left,
            # there might be circular dependencies. Break the cycle by processing one.
            if not processed_any and modules:
                name = next(iter(modules))
                lines += modules[name].convert_to_cmake()
                lines.append("")
                processed_modules.add(name)
                del modules[name]

        # Add subdirectories if provided
        if subdirectories:
            for subdir in subdirectories:
                lines.append(f"add_subdirectory({subdir})")
            lines.append("")

        return "\n".join(lines)
