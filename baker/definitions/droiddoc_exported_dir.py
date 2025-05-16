from ..blueprint import ast
from .module import Module
from .utils import Utils

class DroiddocExportedDir(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name == "droiddoc_exported_dir"

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        path = self._get_property("path")

        lines.append(f'add_library({name} INTERFACE)')
        lines.append(f'target_include_directories({name} INTERFACE {Utils.to_cmake_expression(path, lines)})')

        return lines
