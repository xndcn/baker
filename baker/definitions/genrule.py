from ..blueprint import ast
from .module import Module
from .utils import Utils

class GenRule(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("genrule") >= 0

    def _convert_out_to_cmake(self, out_var: str) -> list[str]:
        lines = []
        out = self._get_property("out")
        lines.append(f'set({out_var} {Utils.to_cmake_expression(out, lines)})')
        return lines

    def _add_custom_command(self, name: str, gen_target: str) -> list[str]:
        lines = []
        # add_custom_command OUTPUT do not support generator expressions of target, so create a variable
        out = Utils.to_internal_name(name, "OUT")
        lines += self._convert_out_to_cmake(out)
        lines.append(f'''add_custom_command(
                        OUTPUT "$<LIST:TRANSFORM,${{{out}}},PREPEND,${{CMAKE_CURRENT_BINARY_DIR}}/gen/>"
                        COMMAND ${{CMAKE_SOURCE_DIR}}/cmake/genrule.sh ARGS
                            --cmd "$<TARGET_PROPERTY:{gen_target},_cmd>"
                            --genDir "${{CMAKE_CURRENT_BINARY_DIR}}/gen/"
                            --outs "${{{out}}}"
                            --srcs "$<PATH:RELATIVE_PATH,$<TARGET_PROPERTY:{gen_target},INTERFACE_SOURCES>,${{CMAKE_CURRENT_SOURCE_DIR}}>"
                            --tools "$<GENEX_EVAL:$<TARGET_PROPERTY:{gen_target},_tools>>"
                            --tool_files "$<GENEX_EVAL:$<TARGET_PROPERTY:{gen_target},_tool_files>>"
                        WORKING_DIRECTORY ${{CMAKE_CURRENT_SOURCE_DIR}}
                        DEPENDS $<GENEX_EVAL:$<TARGET_PROPERTY:{gen_target},_tools>> ; $<GENEX_EVAL:$<TARGET_PROPERTY:{gen_target},_tool_files>> ; {gen_target} ; $<TARGET_PROPERTY:{gen_target},INTERFACE_LINK_LIBRARIES>
                        VERBATIM
                    )''')
        lines.append(f'add_custom_target({name}-gen SOURCES "$<LIST:TRANSFORM,${{{out}}},PREPEND,${{CMAKE_CURRENT_BINARY_DIR}}/gen/>")')
        return lines

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")

        srcs = self._get_property("srcs")
        gen = Utils.to_internal_name(name, "GEN")
        lines.append(f'add_library({gen} INTERFACE)')
        lines.append(f'target_sources({gen} INTERFACE {Utils.to_cmake_expression(srcs, lines)})')
        lines.append(f'baker_apply_sources_transform({gen})')
        lines += self._convert_internal_properties_to_cmake(self._module.properties, gen, set())
        lines.append(f'baker_apply_genrule_transform({gen})')
        lines += self._add_custom_command(name, gen)
        lines.append(f'add_library({name} INTERFACE)')
        lines.append(f'target_include_directories({name} INTERFACE ${{CMAKE_CURRENT_BINARY_DIR}}/gen/)')
        lines.append(f'target_sources({name} INTERFACE $<TARGET_PROPERTY:{name}-gen,SOURCES>)')
        lines.append(f'add_dependencies({name} {name}-gen)')

        return lines
