from ..blueprint import ast

class Utils:
    @classmethod
    def type_of_variable(cls, root: ast.Blueprint, name: str) -> type:
        expr = root.variables[name].value
        value = cls.evaluate_expression(root, expr)
        return cls.type_of_expression(root, expr, value)

    @classmethod
    def type_of_expression(cls, root: ast.Blueprint, expr: ast.Node, value: any) -> type:
        if isinstance(expr, ast.VariableValue):
            expr = root.variables[expr.name].value
            value = cls.evaluate_expression(root, expr)
            return cls.type_of_expression(root, expr, value)
        return type(value)

    @classmethod
    def evaluate_expression(cls, root: ast.Blueprint, expr: ast.Node):
        if expr is None:
            return None

        if isinstance(expr, ast.Expression):
            base_value = cls.evaluate_expression(root, expr.value)
            if expr.operator:
                right_value = cls.evaluate_expression(root, expr.operator)
                base_type = cls.type_of_expression(root, expr.value, base_value)
                right_type = cls.type_of_expression(root, expr.operator, right_value)
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
            return [cls.evaluate_expression(root, element) for element in expr.elements]
        elif isinstance(expr, ast.MapValue):
            return {key: cls.evaluate_expression(root, value) for key, value in expr.properties.items()}
        elif isinstance(expr, ast.VariableValue):
            return expr
        elif isinstance(expr, ast.SelectValue):
            return expr

        # default case
        return expr

    @classmethod
    def to_cmake_expression(cls, value, lines: list[str]) -> str:
        if value is None:
            return ""
        elif isinstance(value, bool):
            return "ON" if value else "OFF"  # CMake uses ON/OFF for booleans
        elif isinstance(value, int):
            return str(value)
        elif isinstance(value, str):
            # Use bracket argument if contains special CMake characters
            if any(c in value for c in ";()#$ \t\n\"'\\"):
                return f'[=[{value}]=]'
            return f'"{value}"'
        elif isinstance(value, list):
            # For lists, join elements with semicolons which is CMake's list separator
            elements = [cls.to_cmake_expression(elem, lines) for elem in value]
            return " ; ".join(elements)
        elif isinstance(value, ast.VariableValue):
            return f"${{{value.name}}}"
        elif isinstance(value, ast.SelectValue):
            conditions = [f'{condition.name}_{"-".join(condition.args)}' for condition in value.conditions]
            var_name = f'_select_{"+".join(conditions)}'

            def condition_to_cmake(condition: ast.SelectCondition) -> str:
                args = [f'"{arg}"' for arg in condition.args]
                return f'{condition.name}({",".join(args)})'
            
            def patterns_to_cmake(patterns: list[ast.SelectPattern]) -> tuple[str, list[str]]:
                patterns = list(filter(lambda p: p.pattern != "default", patterns))
                checks = []
                bindings = []
                for i, pattern in enumerate(patterns):
                    if pattern.pattern == "any" and pattern.binding is not None:
                        bindings.append((pattern.binding, value.conditions[i]))
                        checks.append(f'TRUE')
                    elif pattern.pattern == "default":
                        checks.append(f'TRUE')
                    elif isinstance(pattern.pattern, ast.BooleanValue):
                        checks.append(condition_to_cmake(value.conditions[i]))
                    elif isinstance(pattern.pattern, ast.StringValue):
                        checks.append(f'{condition_to_cmake(value.conditions[i])} STREQUAL "{pattern.pattern.value}"')
                print([str(p) for p in patterns], checks)
                checks = f'({" AND ".join(checks)})' if len(checks) > 1 else checks[0]
                bindings = [f'set({binding} {condition_to_cmake(condition)})' for binding, condition in bindings]
                return checks, bindings

            def case_to_cmake(var_name: str, case: ast.SelectCase) -> str:
                if case.is_unset:
                    return f"unset({var_name})"
                else:
                    # Evaluate without the root blueprint
                    value = cls.evaluate_expression(None, case.value)
                    return f"set({var_name} {cls.to_cmake_expression(value, [])})"

            # Find the default case and filter it out from cases
            default_case = next(filter(lambda case: all(pattern.pattern == "default" for pattern in case.patterns), value.cases), None)
            cases = list(filter(lambda case: case != default_case, value.cases))

            # Generate CMake code for checking the conditions and setting the variable
            for i, case in enumerate(cases):
                checks, bindings = patterns_to_cmake(case.patterns)
                if i == 0:
                    lines.append(f"if({checks})")
                else:
                    lines.append(f"elseif({checks})")
                if bindings:
                    lines += ["    " + line for line in bindings]
                lines.append(f"    {case_to_cmake(var_name, case)}")
            if default_case:
                lines.append(f"else()")
                lines.append(f"    {case_to_cmake(var_name, default_case)}")
            lines.append("endif()")
            return f"${{{var_name}}}"
        else:
            # default case, convert to string
            return str(value)

    @classmethod
    def to_internal_name(cls, target: str, postfix: str) -> str:
        if target.startswith('.'):
            return f"{target}.{postfix}"
        return f".{target}.{postfix}"


    @classmethod
    def get_property(cls, root: ast.Blueprint, properties: dict, name: str, default=None) -> any:
        if name in properties:
            return Utils.evaluate_expression(root, properties[name])
        return default