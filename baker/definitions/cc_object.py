from ..blueprint import ast
from .module import Module

class CCObject(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_object") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")

        # cc_object is one object by partial linking of multiple object files
        lines.append(f'add_executable({name})')
        lines += self._convert_module_properties_to_cmake(name)
        # Always enable position independent code
        lines.append(f'set_target_properties({name} PROPERTIES POSITION_INDEPENDENT_CODE ON)')
        lines.append(f'set_target_properties({name} PROPERTIES SUFFIX .o ENABLE_EXPORTS ON)')
        # Set the linker to use the partial linking option
        lines.append(f'target_link_options({name} PRIVATE -no-pie -nostdlib -Wl,-r)')
        lines.append(f'target_link_libraries({name} INTERFACE $<TARGET_FILE:{name}>)')
        return lines