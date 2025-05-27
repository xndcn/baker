from ...blueprint import ast
from .cc_module import CCModule

class CCTest(CCModule):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_test") >= 0

    def _cmake_function_name(self) -> str:
        return "baker_cc_test"