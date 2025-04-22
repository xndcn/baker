from ..blueprint import ast
from .module import Module
from .utils import Utils

class CCAConfigLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_aconfig_library") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name") + '-static'
        aconfig_declarations = self._get_property("aconfig_declarations")
        lines.append(f'add_library({name} STATIC)')
        lines += self._convert_internal_properties_to_cmake(self._module.properties, name, set(), set())
        # add_custom_command OUTPUT can not contains generator expressions with target property
        # so use get_property here
        lines.append(f'get_property(package TARGET {Utils.to_cmake_expression(aconfig_declarations, lines)} PROPERTY _package)')
        lines.append(f'set(package $<LIST:TRANSFORM,${{package}},REPLACE,[.],_>)')
        lines.append(f'''add_custom_command(
                        OUTPUT "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/${{package}}.cc" ; "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/include/${{package}}.h"
                        COMMAND aconfig ARGS create-cpp-lib
                            --cache "$<TARGET_PROPERTY:$<TARGET_PROPERTY:{name},_aconfig_declarations>,_srcs>"
                            --out "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/"
                        WORKING_DIRECTORY ${{CMAKE_CURRENT_SOURCE_DIR}}
                        DEPENDS $<TARGET_PROPERTY:{name},_aconfig_declarations>
                        VERBATIM
                    )''')
        # Create the gen directory if it doesn't exist
        lines.append(f'file(MAKE_DIRECTORY "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/")')
        lines.append(f'target_sources({name} PRIVATE ${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/${{package}}.cc)')
        lines.append(f'target_include_directories({name} PUBLIC ${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/include)')
        return lines
