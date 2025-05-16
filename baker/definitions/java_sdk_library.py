from ..blueprint import ast
from .module import Module
from .utils import Utils

class JavaSdkLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_sdk_library") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        lines.append(f'add_library({name} INTERFACE)')
        if srcs := self._get_property("srcs"):
            lines.append(f'target_sources({name} INTERFACE {Utils.to_cmake_expression(srcs, lines)})')
        lines.append(f'baker_apply_sources_transform({name})')
        if defaults := self._get_property("defaults"):
            lines.append(f'target_link_libraries({name} INTERFACE {Utils.to_cmake_expression(defaults, lines)})')
        single_keys = set()
        list_keys = set()
        lines += self._convert_internal_properties_to_cmake(self._module.properties, name, single_keys, list_keys)
        if single_keys:
            lines.append(f'set_property(TARGET {name} PROPERTY _ALL_SINGLE_KEYS_ {Utils.to_cmake_expression(list(single_keys), [])})')
        if list_keys:
            lines.append(f'set_property(TARGET {name} PROPERTY _ALL_LIST_KEYS_ {Utils.to_cmake_expression(list(list_keys), [])})')
        lines.append(f'baker_add_java_sdk_library({name})')
        return lines