from ..blueprint import ast
from .module import Module
from .utils import Utils

class CCLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_library") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")

        object = Utils.to_internal_name(name, "OBJ")
        lines.append(f'add_library({object} OBJECT)')
        # hack for header only library, which is hard to determine whether it contains srcs
        lines.append(f'target_sources({object} PUBLIC ".")')
        lines.append(f'set_target_properties({object} PROPERTIES LINKER_LANGUAGE CXX)')
        # Always enable position independent code
        lines.append(f'set_target_properties({object} PROPERTIES POSITION_INDEPENDENT_CODE ON)')

        lines += self._convert_module_properties_to_cmake(object)

        # Handle static and shared libraries
        # CMake object library will propagate the interface libraries
        # So we can not directly PUBLIC link the object library
        if not self._module.name.endswith("_static"):
            lines.append(f'add_library({name}-shared SHARED)')
            lines.append(f'target_link_libraries({name}-shared PRIVATE {object})')
            lines.append(f'target_link_libraries({name}-shared INTERFACE $<TARGET_GENEX_EVAL:{object},$<TARGET_PROPERTY:{object},__export_libs>>)')
            lines.append(f'target_include_directories({name}-shared INTERFACE $<TARGET_GENEX_EVAL:{object},$<TARGET_PROPERTY:{object},__export_dirs>>)')
            lines.append(f'set_target_properties({name}-shared PROPERTIES PREFIX "" OUTPUT_NAME {Utils.to_cmake_expression(name)})')
            lines.append(f'set_target_properties({name}-shared PROPERTIES LINKER_LANGUAGE CXX)')
        if not self._module.name.endswith("_shared"):
            lines.append(f'add_library({name}-static STATIC)')
            lines.append(f'target_link_libraries({name}-static PRIVATE {object})')
            lines.append(f'target_link_libraries({name}-static INTERFACE $<TARGET_GENEX_EVAL:{object},$<TARGET_PROPERTY:{object},__export_libs>>)')
            lines.append(f'target_include_directories({name}-static INTERFACE $<TARGET_GENEX_EVAL:{object},$<TARGET_PROPERTY:{object},__export_dirs>>)')
            lines.append(f'set_target_properties({name}-static PROPERTIES PREFIX "" OUTPUT_NAME {Utils.to_cmake_expression(name)})')
            lines.append(f'set_target_properties({name}-static PROPERTIES LINKER_LANGUAGE CXX)')
        # Add alias for static only library
        if self._module.name.endswith("_static"):
            lines.append(f'add_library({name} ALIAS {name}-static)')
        else:
            lines.append(f'add_library({name} ALIAS {name}-shared)')

        return lines