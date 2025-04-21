from ..blueprint import ast
from .module import Module
from .utils import Utils

class PythonBinaryHost(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("python_binary_host") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        # Handle stem (output binary name)
        stem = self._get_property("stem", default=name)
        suffix = self._get_property("suffix", default="")
        binary_name = f"{stem}{suffix}"

        lines.append(f'add_executable({name} IMPORTED GLOBAL)')
        lines.append(f'set_property(TARGET {name} PROPERTY IMPORTED_LOCATION ${{CMAKE_CURRENT_BINARY_DIR}}/{binary_name})')
        lines += self._convert_internal_properties_to_cmake(self._module.properties, name, keys=set())

        # Get the main file, use module name + .py if not specified
        main_py = self._get_property("main", default=f"{name}.py")
        # Create a Python executable wrapper script
        lines.append(f'''file(GENERATE OUTPUT ${{CMAKE_CURRENT_BINARY_DIR}}/{binary_name}
                        INPUT ${{CMAKE_SOURCE_DIR}}/cmake/python_binary_host.template.sh
                        TARGET {name}
                        USE_SOURCE_PERMISSIONS
                     )''')
        return lines
