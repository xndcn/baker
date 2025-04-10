from ..blueprint import ast
from .module import Module
from .utils import Utils

class AIDLInterface(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("aidl_interface") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        if srcs := self._get_property("srcs"):
            lines.append(f'file(GLOB_RECURSE {Utils.to_internal_name(name, "SRCS")} {Utils.to_cmake_expression(srcs)})')
        lines.append(f'add_aidl_library({name} SRCS {Utils.to_internal_name(name, "SRCS")} LANG)')
        lines += self._convert_module_properties_to_cmake(name)
        return lines