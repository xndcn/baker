from ..blueprint import ast
from .module import Module
from .utils import Utils

class GenRule(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("genrule") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")

        srcs = self._get_property("srcs")
        gen = Utils.to_internal_name(name, "GEN")
        lines.append(f'add_library({gen} INTERFACE)')
        lines.append(f'target_sources({gen} INTERFACE {Utils.to_cmake_expression(srcs)})')
        lines.append(f'baker_apply_sources_transform({gen})')
        lines += self._convert_internal_properties_to_cmake(self._module.properties, gen, set())
        lines.append(f'baker_apply_genrule_transform({gen})')

        out = self._get_property("out")
        # add_custom_command OUTPUT do not support generator expressions of target, so create a variable
        lines.append(f'set(OUT {Utils.to_cmake_expression(out)})')
        lines.append(f'set({Utils.to_internal_name(name, "OUT")} $<LIST:TRANSFORM,${{OUT}},PREPEND,${{CMAKE_CURRENT_BINARY_DIR}}/gen/>)')
        lines.append(f'''add_custom_command(
                        OUTPUT ${{{Utils.to_internal_name(name, "OUT")}}}
                        COMMAND ${{CMAKE_SOURCE_DIR}}/cmake/genrule.sh ARGS
                            --cmd "$<TARGET_PROPERTY:{gen},_cmd>"
                            --genDir "${{CMAKE_CURRENT_BINARY_DIR}}/gen/"
                            --outs "${{OUT}}"
                            --srcs "$<TARGET_PROPERTY:{gen},INTERFACE_SOURCES>"
                            --tools "$<TARGET_GENEX_EVAL:{gen},$<TARGET_PROPERTY:{gen},_tools>>"
                            --tool_files "$<TARGET_PROPERTY:{gen},_tool_files>"
                        DEPENDS $<TARGET_GENEX_EVAL:{gen},$<TARGET_PROPERTY:{gen},_tools>> ; $<TARGET_PROPERTY:{gen},_tool_files> ; {gen}
                        VERBATIM
                     )''')
        lines.append(f'add_custom_target({name} SOURCES ${{{Utils.to_internal_name(name, "OUT")}}})')
        lines.append(f'add_library({name}-gen INTERFACE)')
        lines.append(f'target_include_directories({name}-gen INTERFACE ${{CMAKE_CURRENT_BINARY_DIR}}/gen/)')
        lines.append(f'add_dependencies({name}-gen {name})')

        return lines
