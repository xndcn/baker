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
        lines = []
        def add_property(key: str, value) -> list[str]:
            lines = []
            if not isinstance(value, dict):
                _key = f"_{key}"
                lines.append(f'set_property(TARGET {name} APPEND PROPERTY {_key} {Utils.to_cmake_expression(value)})')
                keys.add(_key)
            else:
                for k, v in value.items():
                    lines += add_property(f'{key}_{k}', v)
            return lines

        # Add properties
        for key, value in properties.items():
            if key in ["name", "srcs", "target"]:
                continue
            lines += add_property(key, self._evaluate_expression(value))
        # Add target properties
        lines += self._convert_target_properties_to_cmake(properties, name, lambda target_properties, name:
            self._convert_to_cmake(target_properties, name, keys))

        if srcs := Utils.get_property(self._blueprint, properties, "srcs"):
            lines.append(f'file(GLOB_RECURSE {Utils.to_internal_name(name, "SRCS")} {Utils.to_cmake_expression(srcs)})')
            lines.append(f'target_sources({name} INTERFACE ${{{Utils.to_internal_name(name, "SRCS")}}})')
        if defaults := Utils.get_property(self._blueprint, properties, "defaults"):
            lines.append(f'inherit_defaults({name} {Utils.to_cmake_expression(defaults)})')
        return lines

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        lines.append(f'add_library({name} INTERFACE)')
        keys = set()
        lines += self._convert_to_cmake(self._module.properties, name, keys)
        # Add keys to the target
        if keys:
            lines.append(f'set_property(TARGET {name} PROPERTY _ALL_KEYS_ {Utils.to_cmake_expression(list(keys))})')

        return lines
