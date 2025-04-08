from ..blueprint import ast
from .module import Module

class CCBinary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_binary") >= 0

    def convert_to_cmake(self):
        lines = []
        name = self._get_property("name")

        lines.append(f'add_executable({name})')
        lines += self._convert_module_properties_to_cmake(name)

        return lines