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
            return f"${{{expr.name}}}"
        elif isinstance(expr, ast.SelectValue):
            return f'${{select_ + {"_".join(condition.name for condition in expr.conditions)}}}'

        # default case
        return expr

    @classmethod
    def to_cmake_expression(cls, value):
        if value is None:
            return ""
        elif isinstance(value, bool):
            return "ON" if value else "OFF"  # CMake uses ON/OFF for booleans
        elif isinstance(value, int):
            return str(value)
        elif isinstance(value, str):
            # Don't quote strings that contain CMake variables (${...})
            if "${" in value and "}" in value:
                return value
            return f'"{value}"'
        elif isinstance(value, list):
            # For lists, join elements with semicolons which is CMake's list separator
            elements = [cls.to_cmake_expression(elem) for elem in value]
            return " ; ".join(elements)
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