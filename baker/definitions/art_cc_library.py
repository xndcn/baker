from ..blueprint import ast
from .cc_library import CCLibrary

class ArtCCLibrary(CCLibrary):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("art_cc_library") >= 0