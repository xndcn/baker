from ..blueprint import ast
from .utils import Utils
from typing import Callable
from abc import ABC, abstractmethod

class Module(ABC):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        self._blueprint = blueprint
        self._module = module

    def _get_property(self, key: str, *, default=None):
        return Utils.get_property(self._blueprint, self._module.properties, key, default)

    def _evaluate_expression(self, expr: ast.Node):
        return Utils.evaluate_expression(self._blueprint, expr)

    def _convert_target_properties_to_cmake(self, properties: dict, name: str, converter: Callable[[dict, str], list[str]]) -> list[str]:
        lines = []
        for key, target_properties in Utils.get_property(self._blueprint, properties, "target", {}).items():
            parts = key.split("_")
            conditions = []
            i = 0
            while i < len(parts):
                # Handle negated conditions (e.g., "not_windows" -> ["not", "windows"])
                if parts[i] == "not" and i + 1 < len(parts):
                    conditions.append(f'NOT "{parts[i+1]}" IN_LIST TARGET')
                    i += 2
                else:
                    conditions.append(f'"{parts[i]}" IN_LIST TARGET')
                    i += 1
            conditions = " AND ".join(f"({c})" for c in conditions) if len(conditions) > 1 else conditions[0]
            lines.append(f'if({conditions})')
            lines += ["  " + line for line in converter(target_properties, name)]
            lines.append('endif()')
        return lines

    def _convert_module_properties_to_cmake(self, name: str) -> list[str]:
        lines = self._convert_common_properties_to_cmake(self._module.properties, name)
        # Some modules need to include themselves
        lines.append(f'target_include_directories({name} PRIVATE ".")')
        return lines

    def _convert_common_properties_to_cmake(self, properties: dict, name: str) -> list[str]:
        lines = []
        if srcs := Utils.get_property(self._blueprint, properties, "srcs"):
            lines.append(f'file(GLOB_RECURSE {Utils.to_internal_name(name, "SRCS")} {Utils.to_cmake_expression(srcs)})')
            lines.append(f'target_sources({name} PRIVATE ${{{Utils.to_internal_name(name, "SRCS")}}})')

        includes = ["include_dirs"]
        headers = ["header_libs", "header_lib_headers"]
        shared_libraries = ["shared_libs"]
        static_libraries = ["whole_static_libs", "static_libs"]

        def get_property(name: str):
            return Utils.get_property(self._blueprint, properties, name)

        if defaults := get_property("defaults"):
            lines.append(f'apply_defaults({name} {Utils.to_cmake_expression(defaults)})')

        # include dirs
        for include in includes:
            if include_dirs := get_property(include):
                lines.append(f'target_include_directories({name} PRIVATE {Utils.to_cmake_expression(include_dirs)})')
            if include_dirs := get_property(f"export_{include}"):
                lines.append(f'target_include_directories({name} PUBLIC {Utils.to_cmake_expression(include_dirs)})')

        # header libs
        for header in headers:
            if header_libs := get_property(header):
                lines.append(f'target_link_libraries({name} PRIVATE {Utils.to_cmake_expression(header_libs)})')
            if header_libs := get_property(f"export_{header}"):
                lines.append(f'target_link_libraries({name} PUBLIC {Utils.to_cmake_expression(header_libs)})')

        # shared libs
        for lib in shared_libraries:
            if shared_libs := get_property(lib):
                lines.append(f'set_property(TARGET {name} PROPERTY _shared_libs {Utils.to_cmake_expression(shared_libs)})')
                shared_libs = f'$<LIST:TRANSFORM,$<TARGET_PROPERTY:{name},_shared_libs>,APPEND,-shared>'
                lines.append(f'target_link_libraries({name} PRIVATE {shared_libs})')
            if shared_libs := get_property(f"export_{lib}"):
                lines.append(f'set_property(TARGET {name} PROPERTY _export_shared_libs {Utils.to_cmake_expression(shared_libs)})')
                shared_libs = f'$<LIST:TRANSFORM,$<TARGET_PROPERTY:{name},_export_shared_libs>,APPEND,-shared>'
                lines.append(f'target_link_libraries({name} PUBLIC {shared_libs})')

        for lib in static_libraries:
            if static_libs := get_property(lib):
                lines.append(f'set_property(TARGET {name} PROPERTY _static_libs {Utils.to_cmake_expression(static_libs)})')
                static_libs = f'$<LIST:TRANSFORM,$<TARGET_PROPERTY:{name},_static_libs>,APPEND,-static>'
                lines.append(f'target_link_libraries({name} PRIVATE {static_libs})')
            if static_libs := get_property(f"export_{lib}"):
                lines.append(f'set_property(TARGET {name} PROPERTY _export_static_libs {Utils.to_cmake_expression(static_libs)})')
                static_libs = f'$<LIST:TRANSFORM,$<TARGET_PROPERTY:{name},_export_static_libs>,APPEND,-static>'
                lines.append(f'target_link_libraries({name} PUBLIC {static_libs})')

        # Process cflags
        if cflags := get_property("cflags"):
            lines.append(f'target_compile_options({name} PRIVATE {Utils.to_cmake_expression(cflags)})')

        # Process all target properties dynamically like linux_glibc
        lines += self._convert_target_properties_to_cmake(properties, name, self._convert_common_properties_to_cmake)
        return lines

    @abstractmethod
    def convert_to_cmake(self) -> list[str]:
        pass