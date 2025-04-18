from ..blueprint import ast
from .module import Module
from .utils import Utils

class AConfigDeclarations(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("aconfig_declarations") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        srcs = self._get_property("srcs")

        gen = Utils.to_internal_name(name, "GEN")
        lines.append(f'add_library({gen} INTERFACE)')
        lines.append(f'target_sources({gen} INTERFACE {Utils.to_cmake_expression(srcs, lines)})')
        lines.append(f'baker_apply_sources_transform({gen})')

        lines.append(f'add_custom_target({name})')
        lines += self._convert_internal_properties_to_cmake(self._module.properties, name, set())
        lines.append(f'''add_custom_command(
                        OUTPUT "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.pb"
                        COMMAND aconfig ARGS create-cache
                            --package "$<TARGET_PROPERTY:{name},_package>"
                            --container "$<TARGET_PROPERTY:{name},_container>"
                            --cache "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.pb"
                            --declarations "$<TARGET_PROPERTY:{gen},INTERFACE_SOURCES>"
                        WORKING_DIRECTORY ${{CMAKE_CURRENT_SOURCE_DIR}}
                        DEPENDS $<TARGET_PROPERTY:{gen},INTERFACE_SOURCES>
                        VERBATIM
                    )''')
        # Create the gen directory if it doesn't exist
        lines.append(f'file(MAKE_DIRECTORY "${{CMAKE_CURRENT_BINARY_DIR}}/gen/")')
        lines.append(f'set_property(TARGET {name} PROPERTY SOURCES ${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.pb)')
        lines.append(f'set_property(TARGET {name} PROPERTY _srcs ${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.pb)')
        return lines