from ...blueprint import ast
from .cc_library import CCLibrary

class CCTestLibrary(CCLibrary):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_test_library") >= 0

    def _cmake_function_name(self) -> str:
        return f"baker_cc_test_library"