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
        if libs := self._get_property("libs"):
            lines.append(f'target_link_libraries({name} INTERFACE {Utils.to_cmake_expression(libs, lines)})')

        # Set up work and output directories
        lines.append(f'set(outDir "${{CMAKE_CURRENT_BINARY_DIR}}/system_modules/{name}")')
        lines.append(f'set(workDir "${{CMAKE_CURRENT_BINARY_DIR}}/modules/{name}")')
        lines.append(f'file(MAKE_DIRECTORY "${{outDir}}" "${{workDir}}/jmod")')
        
        # Add a custom command to generate the system modules using jmod and jlink
        lines.append(f'''add_custom_command(
                        OUTPUT "${{outDir}}/lib/modules"
                        COMMAND ${{CMAKE_COMMAND}} -E env 
                            ${{CMAKE_SOURCE_DIR}}/cmake/jars_to_system_modules.sh
                                --jars "$<TARGET_GENEX_EVAL:{name},$<TARGET_PROPERTY:{name},INTERFACE_LINK_LIBRARIES>>"
                                --outDir "${{outDir}}"
                                --workDir "${{workDir}}"
                        DEPENDS $<TARGET_GENEX_EVAL:{name},$<TARGET_PROPERTY:{name},INTERFACE_LINK_LIBRARIES>>
                        COMMENT "Generating system modules for {name}"
                        VERBATIM
                    )''')
        
        # Add a custom target to ensure the system modules are built
        lines.append(f'add_custom_target({name}-gen DEPENDS "${{outDir}}/lib/modules")')
        lines.append(f'add_dependencies({name} {name}-gen)')
        
        # Set properties to track the output directory
        lines.append(f'set_target_properties({name} PROPERTIES SYSTEM_MODULES_DIR "${{outDir}}")')
        lines.append(f'set_target_properties({name} PROPERTIES SYSTEM_MODULES_DEPS "${{outDir}}/lib/modules")')
        
        return lines
