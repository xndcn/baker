from ..blueprint import ast
from .module import Module
from .utils import Utils

class JavaSdkLibrary(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)

    @staticmethod
    def match(name: str) -> bool:
        return name.find("java_sdk_library") >= 0

    def _get_api_scopes(self):
        """Get the enabled API scopes for this library"""
        scopes = []
        # Default scopes: public is always enabled
        scopes.append("public")
        
        # Check if system and test APIs are enabled
        if self._get_property("generate_system_and_test_apis", False):
            scopes.append("system")
            scopes.append("test")
        
        # Check module_lib scope
        if self._get_property("module_lib", {}).get("enabled", False):
            scopes.append("module_lib")
            
        # Check system_server scope
        if self._get_property("system_server", {}).get("enabled", False):
            scopes.append("system_server")
            
        return scopes

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        api_only = self._get_property("api_only", False)
        shared_library = self._get_property("shared_library", True)
        
        # Get API scopes that should be processed
        api_scopes = self._get_api_scopes()
        
        # Create targets for each API scope
        for scope in api_scopes:
            # Set up stubs library target
            stub_name = f"{name}.stubs{self._get_scope_suffix(scope)}"
            lines.append(f'add_library({stub_name} INTERFACE)')
            
            # Handle scope-specific properties
            scope_props = self._get_property(scope.replace("-", "_"), {})
            scope_libs = scope_props.get("libs", [])
            if scope_libs:
                scope_libs_str = Utils.to_cmake_expression(scope_libs, lines)
                lines.append(f'target_link_libraries({stub_name} INTERFACE {scope_libs_str})')
                
            # Add stub sources directory - typically these would be generated
            # but for CMake we'll assume they're already available
            lines.append(f'target_include_directories({stub_name} INTERFACE "${{CMAKE_CURRENT_SOURCE_DIR}}/stubs/{scope}")')
            
            # Handle the API txt files
            api_dir = self._get_property("api_dir", "api")
            api_prefix = self._get_scope_api_prefix(scope)
            lines.append(f'set_property(TARGET {stub_name} PROPERTY API_TXT_FILE "${{CMAKE_CURRENT_SOURCE_DIR}}/{api_dir}/{api_prefix}current.txt")')
            lines.append(f'set_property(TARGET {stub_name} PROPERTY REMOVED_API_TXT_FILE "${{CMAKE_CURRENT_SOURCE_DIR}}/{api_dir}/{api_prefix}removed.txt")')

        # Create implementation library if not api_only
        if not api_only:
            # Implementation library
            impl_name = f"{name}.impl"
            lines.append(f'add_library({impl_name} SHARED)')
            
            # Add sources to the implementation library
            srcs = self._get_property("srcs", [])
            if srcs:
                lines.append(f'target_sources({impl_name} PRIVATE {Utils.to_cmake_expression(srcs, lines)})')
            
            # Add implementation-specific libraries
            impl_libs = self._get_property("impl_only_libs", [])
            if impl_libs:
                lines.append(f'target_link_libraries({impl_name} PRIVATE {Utils.to_cmake_expression(impl_libs, lines)})')
            
            impl_static_libs = self._get_property("impl_only_static_libs", [])
            if impl_static_libs:
                lines.append(f'target_link_libraries({impl_name} PRIVATE {Utils.to_cmake_expression(impl_static_libs, lines)})')
            
            # Create main library target that depends on the implementation
            lines.append(f'add_library({name} ALIAS {impl_name})')
            
            # If this is a shared library, generate XML permissions file
            if shared_library:
                lines.append(f'# Generate XML permissions file for shared library')
                lines.append(f'set(XML_CONTENT "<?xml version=\\"1.0\\" encoding=\\"utf-8\\"?>\\n<permissions>\\n  <library name=\\"{name}\\"\\n    file=\\"/system/framework/{name}.jar\\"\\n  />\\n</permissions>")')
                lines.append(f'file(WRITE "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.xml" "${{XML_CONTENT}}")')
                lines.append(f'install(FILES "${{CMAKE_CURRENT_BINARY_DIR}}/{name}.xml" DESTINATION ${{CMAKE_INSTALL_PREFIX}}/etc/permissions)')

        return lines

    def _get_scope_suffix(self, scope):
        """Get the suffix for a scope"""
        if scope == "public":
            return ""
        elif scope == "system":
            return ".system"
        elif scope == "test":
            return ".test"
        elif scope == "module_lib":
            return ".module_lib"
        elif scope == "system_server":
            return ".system_server"
        return ""

    def _get_scope_api_prefix(self, scope):
        """Get the API file prefix for a scope"""
        if scope == "public":
            return ""
        elif scope == "system":
            return "system-"
        elif scope == "test":
            return "test-"
        elif scope == "module_lib":
            return "module-lib-"
        elif scope == "system_server":
            return "system-server-"
        return ""
