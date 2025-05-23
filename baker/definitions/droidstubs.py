from ..blueprint import ast
from .module import Module
from .utils import Utils

class Droidstubs(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("droidstubs") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        src = Utils.to_internal_name(name, "SRC")
        lines.append(f'add_library({src} INTERFACE)')
        if srcs := self._get_property("srcs"):
            lines.append(f'target_sources({src} INTERFACE {Utils.to_cmake_expression(srcs, lines)})')
        lines.append(f'baker_apply_sources_transform({src})')

        single_keys = set()
        list_keys = set()
        lines += self._convert_internal_properties_to_cmake(self._module.properties, src, single_keys, list_keys)
        if single_keys:
            lines.append(f'set_property(TARGET {src} PROPERTY _ALL_SINGLE_KEYS_ {Utils.to_cmake_expression(list(single_keys), [])})')
        if list_keys:
            lines.append(f'set_property(TARGET {src} PROPERTY _ALL_LIST_KEYS_ {Utils.to_cmake_expression(list(list_keys), [])})')

        # Add flags to the target
        list_keys.add("_flags")
        lines.append(f'set_property(TARGET {src} APPEND PROPERTY _flags "--exclude-documentation-from-stubs")')

        lines.append(f'baker_add_metalava({src} {name}-metalava)')
        lines.append(f'add_library({name} INTERFACE)')
        lines.append(f'set_target_properties({name} PROPERTIES INTERFACE_SOURCES "@${{CMAKE_CURRENT_BINARY_DIR}}/{src}.metalava.list")')
        lines.append(f'add_dependencies({name} {name}-metalava)')

        return lines
