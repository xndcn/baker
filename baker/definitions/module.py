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

    def _convert_internal_properties_to_cmake(self, properties: dict, name: str, single_keys: set[str], list_keys: set[str]) -> list[str]:
        lines = []
        def add_property(key: str, value) -> list[str]:
            lines = []
            if not isinstance(value, dict):
                _key = f"_{key}"
                if isinstance(value, list):
                    list_keys.add(_key)
                    lines.append(f'set_property(TARGET {name} APPEND PROPERTY {_key} {Utils.to_cmake_expression(value, lines)})')
                else:
                    single_keys.add(_key)
                    lines.append(f'set_property(TARGET {name} PROPERTY {_key} {Utils.to_cmake_expression(value, lines)})')
            else:
                for k, v in value.items():
                    lines += add_property(f'{key}_{k}', v)
            return lines

        # Add properties
        for key, value in properties.items():
            if key in ["name", "srcs", "target"]:
                continue
            lines += add_property(key, self._evaluate_expression(value))
        return lines

    def _convert_module_properties_to_cmake(self, name: str) -> list[str]:
        lines = self._convert_common_properties_to_cmake(self._module.properties, name)
        lines.append(f'baker_apply_sources_transform({name})')
        # Some modules need to include themselves
        lines.append(f'target_include_directories({name} PRIVATE ".")')
        lines.append(f'baker_apply_properties({name} {name})')
        return lines

    def _convert_common_properties_to_cmake(self, properties: dict, name: str) -> list[str]:
        lines = []
        if srcs := Utils.get_property(properties, "srcs"):
            lines.append(f'target_sources({name} PRIVATE {Utils.to_cmake_expression(srcs, lines)})')

        def get_property(name: str):
            return Utils.get_property(properties, name)

        if defaults := get_property("defaults"):
            lines.append(f'baker_apply_defaults({name} {Utils.to_cmake_expression(defaults, lines)})')

        # keys is ignored here for non-defaults modules
        lines += self._convert_internal_properties_to_cmake(properties, name, set(), set())
        # Process all target properties dynamically like linux_glibc
        lines += self._convert_target_properties_to_cmake(properties, name, self._convert_common_properties_to_cmake)
        return lines

    @abstractmethod
    def convert_to_cmake(self) -> list[str]:
        pass