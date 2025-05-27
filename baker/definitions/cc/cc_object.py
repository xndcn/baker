from ...blueprint import ast
from .cc_library import CCLibrary

class CCObject(CCLibrary):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_object") >= 0

    def _cmake_function_name(self) -> str:
        return "baker_cc_object"