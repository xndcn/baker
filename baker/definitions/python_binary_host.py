from ..blueprint import ast
from .module import Module

class PythonBinaryHost(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("python_binary_host") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_python_binary_host")