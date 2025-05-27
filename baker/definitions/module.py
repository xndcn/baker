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

    def _convert_target_properties_to_cmake(self, properties: dict, name: str, converter: Callable[[dict, str], list[str]]) -> list[str]:
        lines = []
        for key, target_properties in Utils.get_property(properties, "target", {}).items():
            parts = key.split("_")
            conditions = []
            i = 0
            while i < len(parts):
                # Handle negated conditions (e.g., "not_windows" -> ["not", "windows"])
                if parts[i] == "not" and i + 1 < len(parts):
                    conditions.append(f'NOT "{parts[i+1]}" IN_LIST TARGET')
                    i += 2
                else:
                    conditions.append(f'"{parts[i]}" IN_LIST TARGET')
                    i += 1
            conditions = " AND ".join(f"({c})" for c in conditions) if len(conditions) > 1 else conditions[0]
            lines.append(f'if({conditions})')
            lines += ["  " + line for line in converter(target_properties, name)]
            lines.append('endif()')
        return lines

    def _convert_condition_properties_to_cmake(self, properties: dict, name: str, converter: Callable[[dict, str], list[str]]) -> list[str]:
        lines = self._convert_target_properties_to_cmake(properties, name, converter)
        conditions = {"arch": "ARCH", "codegen": "CODEGEN"}
        for condition, var in conditions.items():
            for key, condition_properties in Utils.get_property(properties, condition, {}).items():
                lines.append(f'if("{key}" IN_LIST {var})')
                lines += ["  " + line for line in converter(condition_properties, name)]
                lines.append('endif()')
        return lines

    def _convert_internal_properties_to_cmake(self, properties: dict, name: str, single_keys: set[str], list_keys: set[str]) -> list[str]:
        lines = []
        def add_property(key: str, value) -> list[str]:
            lines = []
            if not isinstance(value, dict):
                _key = f"{key}"
                if isinstance(value, list):
                    list_keys.add(_key)
                    lines.append(f'set_property(TARGET {name} APPEND PROPERTY _{_key} {Utils.to_cmake_expression(value, lines)})')
                else:
                    single_keys.add(_key)
                    lines.append(f'set_property(TARGET {name} PROPERTY _{_key} {Utils.to_cmake_expression(value, lines)})')
            else:
                for k, v in value.items():
                    lines += add_property(f'{key}_{k}', v)
            return lines

        # Add properties
        for key, value in properties.items():
            if key in ["name", "srcs", "target", "arch", "codegen"]:
                continue
            lines += add_property(key, self._evaluate_expression(value))
        return lines

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
            if key in ["name", "srcs", "target", "arch", "codegen"]:
                continue
            dicts.update(add_property(key, self._evaluate_expression(value)))
        return dicts

    def _convert_module_to_cmake(self, function: str, internal_name: str = None, scope: str = "PRIVATE") -> list[str]:
        name = self._get_property("name")
        if not internal_name:
            internal_name = name

        single_keys = set()
        list_keys = set()
        properties = self._get_internal_properties(self._module.properties, single_keys, list_keys)
        conditions = self._convert_common_properties_to_cmake(self._module.properties, internal_name, scope, single_keys, list_keys)

        lines = []
        modules = []
        modules.append(f'{function}(')
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
        lines.append(f'baker_apply_sources_transform({internal_name})')
        return lines

    def _convert_common_properties_to_cmake(self, properties: dict, name: str, scope: str, single_keys: set[str], list_keys: set[str]) -> list[str]:
        lines = []
        if properties != self._module.properties:
            if srcs := Utils.get_property(properties, "srcs"):
                lines.append(f'target_sources({name} {scope} {Utils.to_cmake_expression(srcs, lines)})')

        if properties != self._module.properties:
            lines += self._convert_internal_properties_to_cmake(properties, name, single_keys, list_keys)
        # Process all condition properties dynamically like target, arch, codegen
        lines += self._convert_condition_properties_to_cmake(properties, name, lambda condition_properties, name: self._convert_common_properties_to_cmake(condition_properties, name, scope, single_keys, list_keys))
        return lines

    @abstractmethod
    def convert_to_cmake(self) -> list[str]:
        pass
