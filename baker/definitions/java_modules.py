from ..blueprint import ast
from .module import Module

class JavaApiLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_api_library") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_java_api_library")


class JavaSdkLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_sdk_library") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_java_sdk_library")


class JavaSystemModules(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_system_modules") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_java_system_modules")


class JavaLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_library") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_java_library")