from ...blueprint import ast
from .cc_module import CCModule
from ..utils import Utils

class CCLibrary(CCModule):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_library") >= 0

    def _cmake_function_name(self) -> str:
        if self._module.name.endswith("_shared"):
            return f"baker_cc_library_shared"
        elif self._module.name.endswith("_static"):
            return f"baker_cc_library_static"
        return f"baker_cc_library"

    def _convert_module_properties_to_cmake(self, name: str, single_keys: set[str], list_keys: set[str]) -> list[str]:
        name = Utils.to_internal_name(name, "OBJ")
        return super()._convert_module_properties_to_cmake(name, single_keys, list_keys)