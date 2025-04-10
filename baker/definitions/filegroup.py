from ..blueprint import ast
from .module import Module
from .utils import Utils

class FileGroup(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("filegroup") >= 0

    def convert_to_cmake(self):
        lines = []
        name = self._get_property("name")

        lines.append(f'add_library({name} INTERFACE)')
        if srcs := self._get_property("srcs"):
            lines.append(f'target_sources({name} INTERFACE {Utils.to_cmake_expression(srcs)})')
        if path := self._get_property("path"):
            lines.append(f'set_property(TARGET {name} PROPERTY _path {Utils.to_cmake_expression(path)})')
        lines.append(f'baker_apply_sources_transform({name})')
        return lines