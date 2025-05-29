from ..blueprint import ast
from .module import Module
from .utils import Utils

class GenRule(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("genrule") >= 0

    def convert_to_cmake(self):
        name = self._get_property("name")
        src = Utils.to_internal_name(name, "SRC")
        return self._convert_module_to_cmake("baker_genrule", src, "INTERFACE")


class GenSrcs(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("gensrcs") >= 0

    def convert_to_cmake(self):
        name = self._get_property("name")
        src = Utils.to_internal_name(name, "SRC")
        return self._convert_module_to_cmake("baker_gensrcs", src, "INTERFACE")