from ..blueprint import ast
from .module import Module

class AConfigDeclarations(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("aconfig_declarations") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_aconfig_declarations", None, "INTERFACE")


class CCAConfigLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_aconfig_library") >= 0

    def convert_to_cmake(self):
        name = self._get_property("name")
        return self._convert_module_to_cmake("baker_cc_aconfig_library", f"{name}-static", "INTERFACE")