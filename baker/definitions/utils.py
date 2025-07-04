from ..blueprint import ast
import json

class Utils:
    @classmethod
    def type_of_variable(cls, root: ast.Blueprint, name: str) -> type:
        expr = root.variables[name].value
        value = cls.evaluate_expression(expr)
        return cls.type_of_expression(expr, value)

    @classmethod
    def type_of_expression(cls, expr: ast.Node, value: any) -> type:
        if isinstance(expr, ast.VariableValue):
            expr = expr.reference.value
            value = cls.evaluate_expression(expr)
            return cls.type_of_expression(expr, value)
        return type(value)

    @classmethod
    def evaluate_expression(cls, expr: ast.Node):
        if expr is None:
            return None

        if isinstance(expr, ast.Expression):
            base_value = cls.evaluate_expression(expr.value)
            if expr.operator:
                right_value = cls.evaluate_expression(expr.operator)
                base_type = cls.type_of_expression(expr.value, base_value)
                right_type = cls.type_of_expression(expr.operator, right_value)
                if base_type is list or right_type is list:
                    # Handle list concatenation if one of the operands is a variable to a list
                    if not isinstance(base_value, list):
                        base_value = [base_value]
                    if not isinstance(right_value, list):
                        right_value = [right_value]
                    return base_value + right_value
                # FIXME: handle dict variable concatenation
                elif isinstance(base_value, dict) and isinstance(right_value, dict):
                    result = base_value.copy()
                    result.update(right_value)
                    return result
                elif isinstance(base_value, int) and isinstance(right_value, int):
                    return base_value + right_value
                else:
                    return str(base_value) + str(right_value)
            return base_value

        # Process different value types
        elif isinstance(expr, ast.BooleanValue):
            return expr.value
        elif isinstance(expr, ast.IntegerValue):
            return expr.value
        elif isinstance(expr, ast.StringValue):
            return expr.value
        elif isinstance(expr, ast.ListValue):
            return [cls.evaluate_expression(element) for element in expr.elements]
        elif isinstance(expr, ast.MapValue):
            return {key: cls.evaluate_expression(value) for key, value in expr.properties.items()}
        elif isinstance(expr, ast.VariableValue):
            return expr
        elif isinstance(expr, ast.SelectValue):
            return expr

        # default case
        return expr

    @classmethod
    def select_value_to_cmake(cls, value: ast.SelectValue, lines: list[str]) -> str:
        conditions = [f'{condition.name}-{"_".join(condition.args)}' for condition in value.conditions]
        var_name = f'_select_all_{"+".join(conditions)}'

        def condition_out_var_to_cmake(condition: ast.SelectCondition) -> str:
            name = f'{condition.name}-{"_".join(condition.args)}'
            return f'_select_{name}'

        def condition_to_cmake(condition: ast.SelectCondition) -> str:
            args = [f'"{arg}"' for arg in condition.args]
            return f'{condition.name}({condition_out_var_to_cmake(condition)} {" ; ".join(args)})'

        def patterns_to_cmake(patterns: list[ast.SelectPattern]) -> tuple[str, list[str]]:
            patterns = list(filter(lambda p: p.pattern != "default", patterns))
            checks = []
            bindings = []
            for i, pattern in enumerate(patterns):
                out = condition_out_var_to_cmake(value.conditions[i])
                if pattern.pattern == "any" and pattern.binding is not None:
                    bindings.append((pattern.binding, value.conditions[i]))
                    checks.append(f'DEFINED {out}')
                elif pattern.pattern == "default":
                    checks.append(f'TRUE')
                elif isinstance(pattern.pattern, ast.BooleanValue):
                    checks.append(out)
                elif isinstance(pattern.pattern, ast.StringValue):
                    checks.append(f'{out} STREQUAL "{pattern.pattern.value}"')
            checks = " AND ".join(f"({c})" for c in checks) if len(checks) > 1 else checks[0]
            bindings = [f'set({binding} {condition_out_var_to_cmake(condition)})' for binding, condition in bindings]
            return checks, bindings

        def case_to_cmake(var_name: str, case: ast.SelectCase) -> str:
            if case.is_unset:
                return f"unset({var_name})"
            else:
                # Evaluate without the root blueprint
                value = cls.evaluate_expression(case.value)
                return f"set({var_name} {cls.to_cmake_expression(value, [])})"

        # Find the default case and filter it out from cases
        default_case = next(filter(lambda case: all(pattern.pattern == "default" for pattern in case.patterns), value.cases), None)
        cases = list(filter(lambda case: case != default_case, value.cases))

        # Generate conditions function calling
        lines += [condition_to_cmake(c) for c in value.conditions]

        # Generate CMake code for checking the conditions and setting the variable
        for i, case in enumerate(cases):
            checks, bindings = patterns_to_cmake(case.patterns)
            lines.append(f"{'if' if i == 0 else 'elseif'}({checks})")
            if bindings:
                lines += ["    " + line for line in bindings]
            lines.append(f"    {case_to_cmake(var_name, case)}")
        if default_case:
            lines.append(f"else()")
            lines.append(f"    {case_to_cmake(var_name, default_case)}")
        lines.append("endif()")
        return var_name

    @classmethod
    def to_cmake_expression(cls, value, lines: list[str], injson=False) -> str:
        if value is None:
            return ""
        elif isinstance(value, bool):
            return "ON" if value else "OFF"  # CMake uses ON/OFF for booleans
        elif isinstance(value, int):
            return str(value)
        elif isinstance(value, str):
            if injson:
                return value
            # Use bracket argument if contains special CMake characters
            if any(c in value for c in ";()#$ \t\n\"'\\"):
                return f'[=[{value}]=]'
            return f'"{value}"'
        elif isinstance(value, list):
            # For lists, join elements with semicolons which is CMake's list separator
            elements = [cls.to_cmake_expression(elem, lines, injson) for elem in value]
            if elements:
                return " ; ".join(elements)
            elif injson:
                return ""
            else:
                return '""'
        elif isinstance(value, ast.VariableValue):
            return f"${{{value.name}}}"
        elif isinstance(value, ast.SelectValue):
            var_name = cls.select_value_to_cmake(value, lines)
            return f"${{{var_name}}}"
        elif isinstance(value, dict):
            # For dict, convert to a string, which can be parsed by CMake with string(JSON)
            data = {k: cls.to_cmake_expression(v, lines, injson=True) for k, v in value.items()}
            return cls.to_cmake_expression(json.dumps(data), lines)
        else:
            # default case, convert to string
            return str(value)

    @classmethod
    def to_internal_name(cls, target: str, postfix: str) -> str:
        if target.startswith('.'):
            return f"{target}.{postfix}"
        return f".{target}.{postfix}"


    @classmethod
    def get_property(cls, properties: dict, name: str, default=None) -> any:
        if name in properties:
            return Utils.evaluate_expression(properties[name])
        return default