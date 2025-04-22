from ..blueprint import ast
from .module import Module
from .utils import Utils

class Defaults(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("defaults") >= 0

    def _convert_to_cmake(self, properties: dict, name: str, single_keys: set[str], list_keys: set[str]) -> list[str]:
        lines = self._convert_internal_properties_to_cmake(properties, name, single_keys, list_keys)
        # Add target properties
        lines += self._convert_target_properties_to_cmake(properties, name, lambda target_properties, name:
            self._convert_to_cmake(target_properties, name, single_keys, list_keys))

        if srcs := Utils.get_property(properties, "srcs"):
            lines.append(f'target_sources({name} INTERFACE {Utils.to_cmake_expression(srcs, lines)})')
        return lines

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        lines.append(f'add_library({name} INTERFACE)')
        single_keys = set()
        list_keys = set()
        lines += self._convert_to_cmake(self._module.properties, name, single_keys, list_keys)
        # Add keys to the target
        if single_keys:
            lines.append(f'set_property(TARGET {name} PROPERTY _ALL_SINGLE_KEYS_ {Utils.to_cmake_expression(list(single_keys), [])})')
        if list_keys:
            lines.append(f'set_property(TARGET {name} PROPERTY _ALL_LIST_KEYS_ {Utils.to_cmake_expression(list(list_keys), [])})')
        lines.append(f'baker_apply_sources_transform({name})')

        return lines
