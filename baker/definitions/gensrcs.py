from ..blueprint import ast
from .genrule import GenRule
from .utils import Utils

class GenSrcs(GenRule):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("gensrcs") >= 0

    def _convert_out_to_cmake(self, out_var: str, gen_target: str) -> list[str]:
        lines = []
        output_extension = self._get_property("output_extension")
        lines.append(f'baker_get_sources(srcs {gen_target} SCOPE INTERFACE)')
        lines.append(f'set({out_var} "")')
        lines.append(f'foreach(src IN LISTS srcs)')
        lines.append(f'    cmake_path(RELATIVE_PATH src)')
        lines.append(f'    cmake_path(REPLACE_EXTENSION src .{output_extension})')
        lines.append(f'    list(APPEND {out_var} ${{src}})')
        lines.append(f'endforeach()')
        return lines
