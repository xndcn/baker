from ..blueprint import ast
from .genrule import GenRule
from .utils import Utils

class GenSrcs(GenRule):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("gensrcs") >= 0

    def _convert_out_to_cmake(self, out_var: str) -> list[str]:
        lines = []
        srcs = self._get_property("srcs")
        output_extension = self._get_property("output_extension")
        lines.append(f'set({out_var} {Utils.to_cmake_expression(srcs, lines)})')
        lines.append(f'set({out_var} "$<PATH:REPLACE_EXTENSION,${{{out_var}}},.{output_extension}>")')
        return lines
