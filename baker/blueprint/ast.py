class Node:
    def __init__(self):
        pass

    def accept(self, visitor):
        pass


class Blueprint(Node):
    def __init__(self, definitions=None):
        super().__init__()
        self.definitions = definitions or []
        self.variables = {}

    def add_variable(self, assignment):
        if assignment.name not in self.variables:
            self.variables[assignment.name] = assignment.value

    def accept(self, visitor):
        return visitor.visit_blueprint(self)

    def __str__(self):
        return f"Blueprint(definitions[{len(self.definitions)}])"


class Assignment(Node):
    def __init__(self, name, value, append=False):
        super().__init__()
        self.name = name
        self.value = value
        self.append = append

    def accept(self, visitor):
        return visitor.visit_assignment(self)

    def __str__(self):
        op = "+=" if self.append else "="
        return f"Assignment({self.name} {op} {self.value})"


class Module(Node):
    def __init__(self, name, properties=None):
        super().__init__()
        self.name = name
        self.properties = properties or {}

    def accept(self, visitor):
        return visitor.visit_module(self)

    def __str__(self):
        return f"Module({self.name}, properties[{len(self.properties)}])"


class Property(Node):
    def __init__(self, name, value):
        super().__init__()
        self.name = name
        self.value = value

    def accept(self, visitor):
        return visitor.visit_property(self)

    def __str__(self):
        return f"Property({self.name}: {self.value})"


class Expression(Node):
    def __init__(self, value, operator=None):
        super().__init__()
        self.value = value
        self.operator = operator

    def accept(self, visitor):
        return visitor.visit_expression(self)

    def __str__(self):
        op_str = f" + {self.operator}" if self.operator else ""
        return f"Expression({self.value}{op_str})"


class BooleanValue(Node):
    def __init__(self, value):
        super().__init__()
        self.value = value

    def accept(self, visitor):
        return visitor.visit_boolean_value(self)

    def __str__(self):
        return f"Boolean({self.value})"


class IntegerValue(Node):
    def __init__(self, value):
        super().__init__()
        self.value = value

    def accept(self, visitor):
        return visitor.visit_integer_value(self)

    def __str__(self):
        return f"Integer({self.value})"


class StringValue(Node):
    def __init__(self, value):
        super().__init__()
        self.value = value

    def accept(self, visitor):
        return visitor.visit_string_value(self)

    def __str__(self):
        return f"String({self.value})"


class ListValue(Node):
    def __init__(self, elements=None):
        super().__init__()
        self.elements = elements or []

    def accept(self, visitor):
        return visitor.visit_list_value(self)

    def __str__(self):
        return f"List(elements[{len(self.elements)}])"


class MapValue(Node):
    def __init__(self, properties=None):
        super().__init__()
        self.properties = properties or {}

    def accept(self, visitor):
        return visitor.visit_map_value(self)

    def __str__(self):
        return f"Map(properties[{len(self.properties)}])"


class VariableValue(Node):
    def __init__(self, blueprint: Blueprint, name):
        super().__init__()
        self.name = name
        self.reference = blueprint.variables.get(self.name)

    def accept(self, visitor):
        return visitor.visit_variable_value(self)

    def __str__(self):
        return f"Variable({self.name})"


class SelectValue(Node):
    def __init__(self, conditions, cases):
        super().__init__()
        self.conditions = conditions
        self.cases = cases

    def accept(self, visitor):
        return visitor.visit_select_value(self)

    def __str__(self):
        return f"Select({self.conditions}, cases[{len(self.cases)}])"


class SelectCondition(Node):
    def __init__(self, name, args=None):
        super().__init__()
        self.name = name
        self.args = args or []

    def accept(self, visitor):
        return visitor.visit_condition(self)

    def __str__(self):
        return f"Condition({self.name}({', '.join(self.args)}))"


class SelectCase(Node):
    def __init__(self, patterns, value):
        super().__init__()
        self.patterns = patterns if isinstance(patterns, list) else [patterns]
        self.value = value
        self.is_unset = value == "unset"

    def accept(self, visitor):
        return visitor.visit_select_case(self)

    def __str__(self):
        value_str = "unset" if self.is_unset else str(self.value)
        return f"Case({self.patterns}: {value_str})"


class SelectPattern(Node):
    def __init__(self, pattern, binding=None):
        super().__init__()
        self.pattern = pattern  # can be 'any', 'default', boolean or string
        self.binding = binding

    def accept(self, visitor):
        return visitor.visit_select_pattern(self)

    def __str__(self):
        binding_str = f"@{self.binding}" if self.binding else ""
        return f"Pattern({self.pattern}{binding_str})"
