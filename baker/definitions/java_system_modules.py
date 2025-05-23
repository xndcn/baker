from ..blueprint import ast
from .module import Module
from .utils import Utils

class JavaSystemModules(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_system_modules") >= 0 and not name.find("java_system_modules_import") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        lines.append(f'add_library({name} INTERFACE)')
        lines.append(f'set(jars "")')
        if libs := self._get_property("libs"):
            lines.append(f'set(libs {Utils.to_cmake_expression(libs, lines)})')
            lines.append(f'target_link_libraries({name} INTERFACE ${{libs}})')
            lines.append(f'foreach(lib IN LISTS libs)')
            lines.append(f'    list(APPEND jars "$<$<TARGET_EXISTS:${{lib}}>:$<TARGET_PROPERTY:${{lib}},_classpath>>")')
            lines.append(f'endforeach()')

        # Set up work and output directories
        out_dir = f"${{CMAKE_CURRENT_BINARY_DIR}}/system_modules/{name}"
        # Add a custom command to generate the system modules using jmod and jlink
        lines.append(f'''add_custom_command(
                        OUTPUT "{out_dir}/modules/module.jar"
                            "{out_dir}/system/lib/jrt-fs.jar"
                            "{out_dir}/system/lib/modules"
                            "{out_dir}/system/release"
                        COMMAND ${{CMAKE_SOURCE_DIR}}/cmake/java_system_modules.sh
                                --jars "${{jars}}"
                                --outDir "{out_dir}"
                                --moduleVersion "${{Java_VERSION_STRING}}"
                        DEPENDS $<TARGET_PROPERTY:{name},INTERFACE_LINK_LIBRARIES>
                        VERBATIM
                    )''')
        # Add a custom target to ensure the system modules are built
        lines.append(f'add_custom_target({name}-module SOURCES "{out_dir}/system/lib/modules" "{out_dir}/system/lib/jrt-fs.jar")')
        lines.append(f'add_dependencies({name} {name}-module)')
        lines.append(f'set_target_properties({name} PROPERTIES _import_classpath "${{jars}}")')
        lines.append(f'set_target_properties({name} PROPERTIES _classpath "{out_dir}/system/")')


        return lines
