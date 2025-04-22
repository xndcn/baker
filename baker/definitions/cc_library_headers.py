from ..blueprint import ast
from .module import Module
from .utils import Utils

class CCLibraryHeaders(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_library_headers") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")

        lines.append(f'add_library({name} INTERFACE)')
        if include_dirs := self._get_property("export_include_dirs"):
            lines.append(f'target_include_directories({name} INTERFACE {Utils.to_cmake_expression(include_dirs, lines)})')
        if header_libs := self._get_property("export_header_lib_headers"):
            lines.append(f'target_link_libraries({name} INTERFACE {Utils.to_cmake_expression(header_libs, lines)})')
        if shared_libs := self._get_property("export_shared_lib_headers"):
            lines.append(f'target_link_libraries({name} INTERFACE {Utils.to_cmake_expression(shared_libs, lines)})')
        if static_libs := self._get_property("whole_static_libs"):
            lines.append(f'target_link_libraries({name} INTERFACE {Utils.to_cmake_expression(static_libs, lines)})')

        return lines