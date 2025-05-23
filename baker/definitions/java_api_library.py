from ..blueprint import ast
from .module import Module
from .utils import Utils

class JavaApiLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_api_library") >= 0

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        lines.append(f'add_library({name} INTERFACE)')
        if srcs := self._get_property("srcs"):
            lines.append(f'target_sources({name} INTERFACE {Utils.to_cmake_expression(srcs, lines)})')
        lines.append(f'baker_apply_sources_transform({name})')
        if defaults := self._get_property("defaults"):
            lines.append(f'target_link_libraries({name} INTERFACE {Utils.to_cmake_expression(defaults, lines)})')
        if api_contributions := self._get_property("api_contributions"):
            lines.append(f'target_link_libraries({name} INTERFACE {Utils.to_cmake_expression(api_contributions, lines)})')
        lines.append(f'set(classpath "")')
        if libs := self._get_property("libs"):
            lines.append(f'foreach(lib {Utils.to_cmake_expression(libs, lines)})')
            lines.append(f'    list(APPEND classpath "$<TARGET_PROPERTY:${{lib}},_classpath>")')
            lines.append(f'endforeach()')
            lines.append(f'set(classpath "$<JOIN:${{classpath}},:>")')
        single_keys = set()
        list_keys = set()
        lines += self._convert_internal_properties_to_cmake(self._module.properties, name, single_keys, list_keys)
        if single_keys:
            lines.append(f'set_property(TARGET {name} PROPERTY _ALL_SINGLE_KEYS_ {Utils.to_cmake_expression(list(single_keys), [])})')
        if list_keys:
            lines.append(f'set_property(TARGET {name} PROPERTY _ALL_LIST_KEYS_ {Utils.to_cmake_expression(list(list_keys), [])})')
        lines.append(f'file(GENERATE OUTPUT "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.metalava.sh" INPUT "${{CMAKE_SOURCE_DIR}}/cmake/metalava.template.sh" TARGET {name} USE_SOURCE_PERMISSIONS)')
        lines.append(f'''add_custom_command(
                            OUTPUT "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.metalava.list"
                            COMMAND ${{CMAKE_CURRENT_BINARY_DIR}}/{name}.metalava.sh
                                --stubs "${{CMAKE_CURRENT_BINARY_DIR}}/{name}/stubs/"
                                "$<$<BOOL:${{classpath}}>:--classpath;${{classpath}}>"
                                --source-files "$<JOIN:$<TARGET_PROPERTY:{name},INTERFACE_SOURCES>, >" || echo
                            COMMAND find "${{CMAKE_CURRENT_BINARY_DIR}}/{name}/stubs/" -name "*.java" -type f > "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.metalava.list"
                            DEPENDS $<TARGET_PROPERTY:{name},INTERFACE_SOURCES> ; $<TARGET_PROPERTY:{name},_libs>
                            VERBATIM)
                     ''')
        lines.append(f'add_custom_target({name}-metalava SOURCES "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.metalava.list")')
        lines.append(f'''add_custom_command(
                        OUTPUT "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.jar"
                        COMMAND ${{CMAKE_COMMAND}} -E rm -rf "${{CMAKE_CURRENT_BINARY_DIR}}/{name}/classes/" "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.jar"
                        COMMAND ${{Java_JAVAC_EXECUTABLE}}
                            "@${{CMAKE_CURRENT_BINARY_DIR}}/{name}.metalava.list"
                            -source 1.8 -target 1.8
                            "$<$<BOOL:${{classpath}}>:-classpath;${{classpath}}>"
                            -d "${{CMAKE_CURRENT_BINARY_DIR}}/{name}/classes/"
                        COMMAND ${{Java_JAR_EXECUTABLE}}
                            cf "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.jar"
                            -C "${{CMAKE_CURRENT_BINARY_DIR}}/{name}/classes/" .
                        DEPENDS ${{CMAKE_CURRENT_BINARY_DIR}}/{name}.metalava.list $<TARGET_PROPERTY:{name},_libs>
                        VERBATIM COMMAND_EXPAND_LISTS
                    )''')
        lines.append(f'add_custom_target({name}-jar SOURCES "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.jar")')
        lines.append(f'set_target_properties({name} PROPERTIES _classpath "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.jar")')
        lines.append(f'add_dependencies({name} {name}-jar)')

        return lines