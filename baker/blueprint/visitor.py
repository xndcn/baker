from .generated.baker.blueprint.blueprintParser import blueprintParser
from .generated.baker.blueprint.blueprintVisitor import blueprintVisitor
from .ast import *

class AstBuilder(blueprintVisitor):
    def visitBlueprint(self, ctx:blueprintParser.BlueprintContext):
        self._blueprint = Blueprint()
        for def_ctx in ctx.definition():
            self._blueprint.definitions.append(self.visit(def_ctx))
        return self._blueprint

    def visitDefinition(self, ctx:blueprintParser.DefinitionContext):
        if ctx.assignment():
            return self.visit(ctx.assignment())
        else:
            return self.visit(ctx.module())

    def visitAssignment(self, ctx:blueprintParser.AssignmentContext):
        name = ctx.IDENT().getText()
        append = ctx.getChild(1).getText() == '+='
        value = self.visit(ctx.expression())
        assignment = Assignment(name, value, append)
        self._blueprint.add_variable(assignment)
        return assignment

    def visitModule(self, ctx:blueprintParser.ModuleContext):
        name = ctx.IDENT().getText()
        property_list = self.visit(ctx.propertyList())
        return Module(name, property_list)

    def visitPropertyList(self, ctx:blueprintParser.PropertyListContext):
        properties = {}
        if ctx.property_():
            for prop_ctx in ctx.property_():
                prop = self.visit(prop_ctx)
                properties[prop.name] = prop.value
        return properties

    def visitProperty(self, ctx:blueprintParser.PropertyContext):
        name = ctx.IDENT().getText()
        value = self.visit(ctx.expression())
        return Property(name, value)

    def visitExpression(self, ctx:blueprintParser.ExpressionContext):
        value = self.visit(ctx.value())
        operator = None
        if ctx.operator():
            operator = self.visit(ctx.operator())
        return Expression(value, operator)

    def visitOperator(self, ctx:blueprintParser.OperatorContext):
        return self.visit(ctx.expression())

    def visitValue(self, ctx:blueprintParser.ValueContext):
        if ctx.BOOLEAN():
            return BooleanValue(ctx.BOOLEAN().getText() == "true")
        elif ctx.STRING():
            text = ctx.STRING().getText()
            # Remove the surrounding quotes and handle escaped quotes
            return StringValue(text[1:-1].replace('\\"', '"'))
        elif ctx.INTEGER():
            return IntegerValue(int(ctx.INTEGER().getText()))
        elif ctx.variable():
            return self.visit(ctx.variable())
        elif ctx.select():
            return self.visit(ctx.select())
        elif ctx.listValue():
            return self.visit(ctx.listValue())
        else:  # mapValue
            return self.visit(ctx.mapValue())

    def visitSelect(self, ctx:blueprintParser.SelectContext):
        conditions = self.visit(ctx.conditions())
        cases = []
        for case_ctx in ctx.selectCase():
            cases.append(self.visit(case_ctx))
        return SelectValue(conditions, cases)

    def visitVariable(self, ctx:blueprintParser.VariableContext):
        return VariableValue(self._blueprint, ctx.IDENT().getText())

    def visitListValue(self, ctx:blueprintParser.ListValueContext):
        elements = []
        for expr_ctx in ctx.expression():
            elements.append(self.visit(expr_ctx))
        return ListValue(elements)

    def visitMapValue(self, ctx:blueprintParser.MapValueContext):
        properties = self.visit(ctx.propertyList())
        return MapValue(properties)

    def visitConditions(self, ctx:blueprintParser.ConditionsContext):
        conditions = []
        for cond_ctx in ctx.singleCondition():
            conditions.append(self.visit(cond_ctx))
        return conditions

    def visitSingleCondition(self, ctx:blueprintParser.SingleConditionContext):
        name = ctx.IDENT().getText()
        args = []
        for string_ctx in ctx.STRING():
            # Remove the surrounding quotes and handle escaped quotes
            text = string_ctx.getText()
            args.append(text[1:-1].replace('\\"', '"'))
        return SelectCondition(name, args)

    def visitSelectCase(self, ctx:blueprintParser.SelectCaseContext):
        patterns = self.visit(ctx.selectPatterns())

        if ctx.expression():
            value = self.visit(ctx.expression())
        else:  # 'unset'
            value = "unset"

        return SelectCase(patterns, value)

    def visitSelectPatterns(self, ctx:blueprintParser.SelectPatternsContext):
        patterns = []
        for pattern_ctx in ctx.selectOnePattern():
            patterns.append(self.visit(pattern_ctx))
        return patterns

    def visitSelectOnePattern(self, ctx:blueprintParser.SelectOnePatternContext):
        if ctx.BOOLEAN():
            return SelectPattern(self.visitValue(ctx))
        elif ctx.STRING():
            return SelectPattern(self.visitValue(ctx))
        elif ctx.getText() == 'default':
            return SelectPattern('default')
        else:  # 'any' with optional binding
            binding = None
            if ctx.selectBinding():
                binding = self.visit(ctx.selectBinding())
            return SelectPattern('any', binding)

    def visitSelectBinding(self, ctx:blueprintParser.SelectBindingContext):
        return ctx.IDENT().getText()
