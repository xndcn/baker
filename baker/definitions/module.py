from ..blueprint import ast
from .utils import Utils
from typing import Callable
from abc import ABC, abstractmethod

class Module(ABC):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        self._blueprint = blueprint
        self._module = module

    def _get_property(self, key: str, *, default=None):
        return Utils.get_property(self._module.properties, key, default)

    def _evaluate_expression(self, expr: ast.Node):
        return Utils.evaluate_expression(expr)

    def _get_condition_properties(self, properties: dict, condition: str, single_keys: set[str], list_keys: set[str]) -> dict[str, dict[str, any]]:
        dicts = {}
        for key, condition_properties in Utils.get_property(properties, condition, {}).items():
            condition_properties = self._get_internal_properties(condition_properties, single_keys, list_keys)
            dicts[key] = condition_properties
        return dicts

    def _get_internal_properties(self, properties: dict, single_keys: set[str], list_keys: set[str]) -> dict[str, any]:
        dicts = {}
        def add_property(key: str, value) -> dict[str, any]:
            dicts = {}
            if not isinstance(value, dict):
                _key = f"{key}"
                dicts[_key] = value
                if isinstance(value, list):
                    list_keys.add(_key)
                else:
                    single_keys.add(_key)
            else:
                for k, v in value.items():
                    dicts.update(add_property(f'{key}_{k}', v))
            return dicts

        # Add properties
        for key, value in properties.items():
            if key in ["name", "target", "arch", "codegen"]:
                continue
            dicts.update(add_property(key, self._evaluate_expression(value)))
        return dicts

    def _convert_module_to_cmake(self, function: str) -> list[str]:
        name = self._get_property("name")

        single_keys = set()
        list_keys = set()
        properties = self._get_internal_properties(self._module.properties, single_keys, list_keys)

        lines = []
        modules = []
        modules.append(f'{function}(')
        modules.append(f'  name "{name}"')
        for key, value in properties.items():
            modules.append(f'  {key} {Utils.to_cmake_expression(value, lines)}')
        # Process all condition properties dynamically like target, arch, codegen
        for condition in ["target", "arch", "codegen"]:
            for key, properties in self._get_condition_properties(self._module.properties, condition, single_keys, list_keys).items():
                modules.append(f'  _{condition}_ {key}')
                for key, value in properties.items():
                    modules.append(f'    {key} {Utils.to_cmake_expression(value, lines)}')
        modules.append('')
        modules.append(f'  _ALL_SINGLE_KEYS_ {Utils.to_cmake_expression(list(single_keys), [])}')
        modules.append(f'  _ALL_LIST_KEYS_ {Utils.to_cmake_expression(list(list_keys), [])}')
        modules.append(')')
        lines += modules
        return lines

    @abstractmethod
    def convert_to_cmake(self) -> list[str]:
        pass
