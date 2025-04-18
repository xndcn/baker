from ..blueprint import ast
from .module import Module
from .utils import Utils

class AidlInterface(Module):
    def __init__(self, blueprint: ast.Blueprint, module: ast.Module):
        super().__init__(blueprint, module)
        
    @staticmethod
    def match(name: str) -> bool:
        return name.find("aidl_interface") >= 0
    
    def _get_enabled_backends(self):
        backends = []
        java_config = self._get_property("java_config", default={})
        cpp_config = self._get_property("cpp_config", default={})
        ndk_config = self._get_property("ndk_config", default={})
        
        if java_config.get("enabled", False):
            backends.append("java")
        if cpp_config.get("enabled", False):
            backends.append("cpp")
        if ndk_config.get("enabled", False):
            backends.append("ndk")
            
        return backends, {"java": java_config, "cpp": cpp_config, "ndk": ndk_config}
    
    def _handle_version(self, name, version, deps, srcs, stability, backends, config_map, lines):
        """Generate CMake code for a specific version of the interface"""
        version_name = name
        if version and version != "":
            version_name = f"{name}-V{version}"
            
        # Create base AIDL library for this version
        lines.append(f'# AIDL interface {version_name}')
        lines.append(f'add_aidl_library({version_name}')
        
        # Add sources
        if srcs:
            lines.append(f'  SRCS {Utils.to_cmake_expression(srcs)}')
        elif version:
            # Use API files from the specified version
            lines.append(f'  API_DIR "aidl_api/{name}/{version}"')
            
        # Add dependencies
        if deps:
            lines.append(f'  DEPS {Utils.to_cmake_expression(deps)}')
            
        # Add stability flag if provided
        if stability and stability == "vintf":
            lines.append('  FLAGS "--stability=vintf"')
            
        if version and version != "":
            lines.append(f'  VERSION "{version}"')
            
        lines.append(')')
        
        # Generate language-specific backend libraries
        for backend in backends:
            backend_name = f"{version_name}-{backend}"
            config = config_map.get(backend, {})
            
            if backend == "java" and stability == "vintf":
                # Skip Java backend for vintf stability as noted in the Bazel script
                continue
                
            lines.append(f'# {backend} implementation for {version_name}')
            lines.append(f'add_aidl_{backend}_library({backend_name}')
            lines.append(f'  DEPS {version_name}')
            
            # Add backend-specific configuration
            if "min_sdk_version" in config:
                lines.append(f'  MIN_SDK_VERSION {config["min_sdk_version"]}')
                
            if backend in ["cpp", "ndk"]:
                # Add standard dependencies for C++ backends
                if backend == "cpp":
                    lines.append('  SHARED_LIBS libbinder libutils')
                else:  # ndk
                    lines.append('  SHARED_LIBS libbinder_ndk')
                    lines.append('  CPPFLAGS "-DBINDER_STABILITY_SUPPORT"')
                    
                # Add additional dynamic dependencies if specified
                if "additional_dynamic_deps" in config:
                    lines.append(f'  SHARED_LIBS {Utils.to_cmake_expression(config["additional_dynamic_deps"])}')
                    
            lines.append(')')
            
        return version_name
    
    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._get_property("name")
        srcs = self._get_property("srcs")
        deps = self._get_property("deps", default=[])
        stability = self._get_property("stability")
        versions_with_info = self._get_property("versions_with_info", default=[])
        unstable = self._get_property("unstable", default=False)
        frozen = self._get_property("frozen", default=False)
        
        backends, config_map = self._get_enabled_backends()
        
        # Initial checks similar to the Bazel script
        if not versions_with_info and not srcs:
            lines.append('message(FATAL_ERROR "aidl_interface must specify at least versions_with_info or srcs")')
            return lines
            
        if versions_with_info and unstable:
            lines.append('message(FATAL_ERROR "cannot have versions for unstable interface")')
            return lines
            
        if stability and unstable:
            lines.append('message(FATAL_ERROR "stability must be unset when unstable is true")')
            return lines
        
        latest_version_name = None
        next_version = None
        
        # Process all versions in versions_with_info
        if versions_with_info:
            # Sort versions to ensure proper ordering
            sorted_versions = sorted(versions_with_info, key=lambda v: int(v["version"]))
            
            for version_info in sorted_versions:
                version = version_info["version"]
                version_deps = version_info.get("deps", [])
                
                version_name = self._handle_version(
                    name, 
                    version,
                    version_deps + deps,  # Combine version-specific deps with global deps
                    None,  # No srcs for versioned interfaces, will use API dir
                    stability,
                    backends,
                    config_map,
                    lines
                )
                latest_version_name = version_name
            
            # Calculate next version number
            if not unstable:
                next_version = str(int(sorted_versions[-1]["version"]) + 1)
        else:
            # No versions, use "1" as first version if not unstable
            next_version = "" if unstable else "1"
            
        # Create development version if srcs provided
        if srcs:
            dev_version = self._handle_version(
                name,
                next_version,
                deps,
                srcs,
                stability,
                backends,
                config_map,
                lines
            )
            
            # If this is the only version, it becomes the latest
            if not latest_version_name:
                latest_version_name = dev_version
                
        # Create latest version aliases
        if latest_version_name and latest_version_name != name:
            lines.append(f'# Create latest version alias')
            lines.append(f'add_library({name}-latest ALIAS {latest_version_name})')
            
            for backend in backends:
                if backend == "java" and stability == "vintf":
                    continue
                lines.append(f'add_library({name}-latest-{backend} ALIAS {latest_version_name}-{backend})')
                
        return lines
