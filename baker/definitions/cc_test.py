from ..blueprint import ast
from .cc_binary import CCBinary

class CCTest(CCBinary):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_test") >= 0

    def convert_to_cmake(self):
        lines = []
        lines += super().convert_to_cmake()
        name = self._get_property("name")
        lines.append(f'target_link_libraries({name} PRIVATE gtest_main gmock)')
        lines.append(f'add_test(NAME {name} COMMAND {name})')
        return lines