import sys
import os
from antlr4 import FileStream, InputStream, CommonTokenStream, BailErrorStrategy
from .generated.baker.blueprint.blueprintLexer import blueprintLexer
from .generated.baker.blueprint.blueprintParser import blueprintParser
from .visitor import AstBuilder

class Parser:
    def __init__(self):
        self.ast_builder = AstBuilder()

    def parse_file(self, filepath):
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"File {filepath} does not exist")

        input_stream = FileStream(filepath, encoding='utf-8')
        return self.parse_stream(input_stream)

    def parse_string(self, content):
        input_stream = InputStream(content)
        return self.parse_stream(input_stream)

    def parse_stream(self, input_stream):
        lexer = blueprintLexer(input_stream)
        token_stream = CommonTokenStream(lexer)
        parser = blueprintParser(token_stream)

        # Error handling strategy
        parser._errHandler = BailErrorStrategy()

        try:
            tree = parser.blueprint()
            ast = tree.accept(self.ast_builder)
            return ast
        except Exception as e:
            print(f"Error parsing blueprint file: {str(e)}", file=sys.stderr)
            raise