from ..blueprint import ast
from .module import Module
from .utils import Utils

class Defaults(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("defaults") >= 0

    def _convert_conditions_to_cmake(self, properties: dict, name: str, single_keys: set[str], list_keys: set[str]) -> list[str]:
        lines = []
        if properties != self._module.properties:
            lines += self._convert_internal_properties_to_cmake(properties, name, single_keys, list_keys)

        # Add condition properties
        lines += self._convert_condition_properties_to_cmake(properties, name, lambda condition_properties, name:
            self._convert_conditions_to_cmake(condition_properties, name, single_keys, list_keys))

        if properties != self._module.properties:
            if srcs := Utils.get_property(properties, "srcs"):
                lines.append(f'target_sources({name} INTERFACE {Utils.to_cmake_expression(srcs, lines)})')
        return lines

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")

        single_keys = set()
        list_keys = set()
        properties = self._get_internal_properties(self._module.properties, name, single_keys, list_keys)
        conditions = self._convert_conditions_to_cmake(self._module.properties, name, single_keys, list_keys)

        defaults = []
        defaults.append('baker_defaults(')
        defaults.append(f'  name "{name}"')
        if srcs := self._get_property("srcs"):
            defaults.append(f'  srcs {Utils.to_cmake_expression(srcs, lines)}')
        for key, value in properties.items():
            defaults.append(f'  {key} {Utils.to_cmake_expression(value, lines)}')
        defaults.append('')
        defaults.append(f'  _ALL_SINGLE_KEYS_ {Utils.to_cmake_expression(list(single_keys), [])}')
        defaults.append(f'  _ALL_LIST_KEYS_ {Utils.to_cmake_expression(list(list_keys), [])}')
        defaults.append(')')

        lines += defaults
        lines += conditions
        lines.append(f'baker_apply_sources_transform({name})')
        return lines
