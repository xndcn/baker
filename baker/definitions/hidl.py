from ..blueprint import ast
from .module import Module

class HidlInterface(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name == "hidl_interface"

    def convert_to_cmake(self) -> list[str]:
        return self._convert_module_to_cmake("baker_hidl_interface")