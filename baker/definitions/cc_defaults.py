from ..blueprint import ast
from .module import Module
from .utils import Utils

class CCDefaults(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_defaults") >= 0

    def _convert_to_cmake(self, properties: dict, name: str, keys: set[str]) -> list[str]:
        lines = self._convert_internal_properties_to_cmake(properties, name, keys)
        # Add target properties
        lines += self._convert_target_properties_to_cmake(properties, name, lambda target_properties, name:
            self._convert_to_cmake(target_properties, name, keys))

        if srcs := Utils.get_property(properties, "srcs"):
            lines.append(f'target_sources({name} INTERFACE {Utils.to_cmake_expression(srcs, lines)})')
        return lines

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        lines.append(f'add_library({name} INTERFACE)')
        keys = set()
        lines += self._convert_to_cmake(self._module.properties, name, keys)
        # Add keys to the target
        if keys:
            lines.append(f'set_property(TARGET {name} PROPERTY _ALL_KEYS_ {Utils.to_cmake_expression(list(keys), [])})')
        lines.append(f'baker_apply_sources_transform({name})')

        return lines
