from ..blueprint import ast
from .module import Module

class CCBinary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_binary") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_cc_binary")


class CCLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_library") >= 0

    def convert_to_cmake(self):
        function = "baker_cc_library"
        if self._module.name.endswith("_shared"):
            function = "baker_cc_library_shared"
        elif self._module.name.endswith("_static"):
            function = "baker_cc_library_static"
        return self._convert_module_to_cmake(function)


class CCLibraryHeaders(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_library_headers") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_cc_library_headers")


class CCObject(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_object") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_cc_object")


class CCTest(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_test") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_cc_test")


class CCTestLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("cc_test_library") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_cc_test_library")