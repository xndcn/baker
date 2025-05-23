from ..blueprint import ast
from .module import Module
from .utils import Utils

class JavaAConfigLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_aconfig_library") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        lines.append(f'add_library({name} INTERFACE)')
        aconfig_declarations = self._get_property("aconfig_declarations")
        lines += self._convert_internal_properties_to_cmake(self._module.properties, name, set(), set())

        lines.append(f'get_property(package TARGET {Utils.to_cmake_expression(aconfig_declarations, lines)} PROPERTY _package)')
        lines.append(f'set(package $<LIST:TRANSFORM,${{package}},REPLACE,[.],/>)')
        lines.append(f'''set(outputs 
                            "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/${{package}}/Flags.java"
                            "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/${{package}}/CustomFeatureFlags.java"
                            "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/${{package}}/FakeFeatureFlagsImpl.java"
                            "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/${{package}}/FeatureFlagsImpl.java"
                            "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/${{package}}/FeatureFlags.java")
                    ''')
        lines.append(f'''add_custom_command(
                        OUTPUT "${{outputs}}"
                        COMMAND aconfig ARGS create-java-lib
                            --cache "$<TARGET_PROPERTY:$<TARGET_PROPERTY:{name},_aconfig_declarations>,_srcs>"
                            --out "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/"
                        WORKING_DIRECTORY ${{CMAKE_CURRENT_SOURCE_DIR}}
                        DEPENDS $<TARGET_PROPERTY:{name},_aconfig_declarations>
                        VERBATIM
                    )''')

        lines.append('set(flags "")')
        lines.append('set(system_modules "")')
        if system_modules := self._get_property("system_modules"):
            lines.append(f'set(system_modules {Utils.to_cmake_expression(system_modules, lines)})')
            lines.append(f'if(NOT system_modules STREQUAL "none")')
            lines.append(f'    set(flags "--system=$<TARGET_PROPERTY:${{system_modules}},_classpath>")')
            lines.append(f'else()')
            lines.append(f'    set(flags "--system=none")')
            lines.append(f'    set(system_modules "")')
            lines.append(f'endif()')
        
        # Create the gen directory if it doesn't exist
        lines.append(f'file(MAKE_DIRECTORY "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/")')
        lines.append(f'file(GENERATE OUTPUT "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.src" CONTENT "$<JOIN:${{outputs}},\\n>")')

        lines.append(f'''add_custom_command(
                        OUTPUT "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.jar"
                        COMMAND ${{CMAKE_COMMAND}} -E rm -rf "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/classes/" "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.jar"
                        COMMAND ${{Java_JAVAC_EXECUTABLE}}
                            "@${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.src"
                            "--patch-module=java.base=."
                            "${{flags}}"
                            -d "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/classes/"
                        COMMAND ${{Java_JAR_EXECUTABLE}}
                            cf "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.jar"
                            -C "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}/classes/" .
                        DEPENDS ${{outputs}} ${{system_modules}}
                        VERBATIM COMMAND_EXPAND_LISTS
                    )''')

        lines.append(f'add_custom_target({name}-jar SOURCES "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.jar")')
        lines.append(f'set_target_properties({name} PROPERTIES _classpath "${{CMAKE_CURRENT_BINARY_DIR}}/gen/{name}.jar")')
        lines.append(f'add_dependencies({name} {name}-jar)')
        return lines
