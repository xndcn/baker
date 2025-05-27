from ...blueprint import ast
from ..module import Module
from ..utils import Utils
from abc import abstractmethod

class CCModule(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @abstractmethod
    def _cmake_function_name(self) -> str:
        pass

    def _convert_module_properties_to_cmake(self, name: str, single_keys: set[str], list_keys: set[str]) -> list[str]:
        lines = self._convert_common_properties_to_cmake(self._module.properties, name, single_keys, list_keys)
        lines.append(f'baker_apply_sources_transform({name})')
        return lines

    def _convert_common_properties_to_cmake(self, properties: dict, name: str, single_keys: set[str], list_keys: set[str]) -> list[str]:
        lines = []
        if properties != self._module.properties:
            if srcs := Utils.get_property(properties, "srcs"):
                lines.append(f'target_sources({name} PRIVATE {Utils.to_cmake_expression(srcs, lines)})')
            if defaults := Utils.get_property(properties, "defaults"):
                lines.append(f'baker_cc_apply_defaults({name} {Utils.to_cmake_expression(defaults, lines)})')

        if properties != self._module.properties:
            lines += self._convert_internal_properties_to_cmake(properties, name, single_keys, list_keys)
        # Process all condition properties dynamically like target, arch, codegen
        lines += self._convert_condition_properties_to_cmake(properties, name, lambda condition_properties, name: self._convert_common_properties_to_cmake(condition_properties, name, single_keys, list_keys))
        return lines

    def convert_to_cmake(self):
        lines = []
        name = self._get_property("name")

        single_keys = set()
        list_keys = set()
        properties = self._get_internal_properties(self._module.properties, name, single_keys, list_keys)
        conditions = self._convert_module_properties_to_cmake(name, single_keys, list_keys)

        modules = []
        modules.append(f'{self._cmake_function_name()}(')
        modules.append(f'  name "{name}"')
        if srcs := self._get_property("srcs"):
            modules.append(f'  srcs {Utils.to_cmake_expression(srcs, lines)}')
        for key, value in properties.items():
            modules.append(f'  {key} {Utils.to_cmake_expression(value, lines)}')
        modules.append('')
        modules.append(f'  _ALL_SINGLE_KEYS_ {Utils.to_cmake_expression(list(single_keys), [])}')
        modules.append(f'  _ALL_LIST_KEYS_ {Utils.to_cmake_expression(list(list_keys), [])}')
        modules.append(')')

        lines += modules
        lines += conditions
        return lines