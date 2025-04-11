from ..blueprint import ast
from .utils import Utils

class Assignment:
    def __init__(self, blueprint: ast.Blueprint, assignment: ast.Assignment):
        self._blueprint = blueprint
        self._assignment = assignment

    def convert_to_cmake(self) -> list[str]:
        lines = []
        name = self._assignment.name
        value = Utils.evaluate_expression(self._blueprint, self._assignment.value)

        if self._assignment.append and Utils.type_of_expression(self._blueprint, name) is list:
            # FIXME: handle other append types
            lines.append(f'list({name} APPEND {Utils.to_cmake_expression(value)})')
        else:
            lines.append(f'set({name} {Utils.to_cmake_expression(value)})')

        # Special case for "build" assignment
        if name == "build":
            lines.append(f'baker_include_build(${{{name}}})')

        return lines