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


class DroiddocExportedDir(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("droiddoc_exported_dir") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_droiddoc_exported_dir")


class JavaImport(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_import") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_java_import")


class DroidStubs(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("droidstubs") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_droidstubs")


class CombinedApis(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("combined_apis") >= 0

    def convert_to_cmake(self):
        return self._convert_module_to_cmake("baker_combined_apis")