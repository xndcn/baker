from ..blueprint import ast
from .module import Module
from .utils import Utils

class CCLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_library") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")

        object = Utils.to_internal_name(name, "OBJ")
        lines.append(f'add_library({object} OBJECT)')
        # Always enable position independent code
        lines.append(f'set_target_properties({object} PROPERTIES POSITION_INDEPENDENT_CODE ON)')

        lines += self._convert_module_properties_to_cmake(object)

        # Handle static and shared libraries
        if not self._module.name.endswith("_static"):
            lines.append(f'add_library({name}-shared SHARED)')
            lines.append(f'target_link_libraries({name}-shared PUBLIC {object})')
            lines.append(f'set_target_properties({name}-shared PROPERTIES PREFIX "" OUTPUT_NAME {Utils.to_cmake_expression(name)})')
        if not self._module.name.endswith("_shared"):
            lines.append(f'add_library({name}-static STATIC)')
            lines.append(f'target_link_libraries({name}-static PUBLIC {object})')
            lines.append(f'set_target_properties({name}-static PROPERTIES PREFIX "" OUTPUT_NAME {Utils.to_cmake_expression(name)})')
        # Add alias for static only library
        if self._module.name.endswith("_static"):
            lines.append(f'add_library({name} ALIAS {name}-static)')
        else:
            lines.append(f'add_library({name} ALIAS {name}-shared)')

        return lines