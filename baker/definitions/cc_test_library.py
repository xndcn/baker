from ..blueprint import ast
from .module import Module

class CCTestLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_test_library") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")

        lines.append(f'add_library({name}-static STATIC)')
        lines += self._convert_module_properties_to_cmake(f'{name}-static')
        # Always enable position independent code
        lines.append(f'set_target_properties({name}-static PROPERTIES POSITION_INDEPENDENT_CODE ON)')
        lines.append(f'target_link_libraries({name}-static PRIVATE gtest gmock)')
        lines.append(f'add_library({name} ALIAS {name}-static)')
        return lines