from ..blueprint import ast
from .module import Module
from .utils import Utils

class CCObject(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_object") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        object = Utils.to_internal_name(name, "OBJ")
        lines.append(f'add_library({object} OBJECT)')
        lines += self._convert_module_properties_to_cmake(object)
        lines.append(f'baker_add_cc_object({name})')
        return lines