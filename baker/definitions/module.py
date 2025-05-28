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

    def _get_internal_properties(self, properties: dict, name: str, single_keys: set[str], list_keys: set[str]) -> dict[str, any]:
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

        # keys is ignored here for non-defaults modules
        lines += self._convert_internal_properties_to_cmake(properties, name, set(), set())
        # Process all condition properties dynamically like target, arch, codegen
        lines += self._convert_condition_properties_to_cmake(properties, name, self._convert_common_properties_to_cmake)
        return lines

    @abstractmethod
    def convert_to_cmake(self) -> list[str]:
        pass
