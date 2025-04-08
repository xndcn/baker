import os
import subprocess
from setuptools import setup, find_packages, Command
from setuptools.command.develop import develop
from setuptools.command.build_py import build_py

class GenerateAntlrParser(Command):
    """Custom command to generate ANTLR4 parser files from grammar."""
    description = 'Generate ANTLR4 parser from blueprint.g4 grammar'
    user_options = []

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        grammar_file = os.path.join('baker', 'blueprint', 'blueprint.g4')
        output_dir = os.path.join('baker', 'blueprint', 'generated')

        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)

        antlr_cmd = ['antlr4']

        # Run ANTLR code generation
        cmd = antlr_cmd + [
            '-Dlanguage=Python3',
            '-visitor',
            '-no-listener',
            '-o', output_dir,
            grammar_file
        ]

        self.announce(f'Generating ANTLR4 parser: {" ".join(cmd)}', level=2)
        subprocess.check_call(cmd)
        self.announce('ANTLR4 parser generated successfully', level=2)

class BuildPyCommand(build_py):
    """Custom build command to include ANTLR generation"""
    def run(self):
        self.run_command('generate_parser')
        build_py.run(self)

class DevelopCommand(develop):
    """Custom develop command to include ANTLR generation"""
    def run(self):
        self.run_command('generate_parser')
        develop.run(self)

setup(
    name="baker",
    version="0.1.0",
    description="Blueprint (Android.bp) to CMakeLists.txt converter",
    author="xndcn",
    author_email="xndchn@gmail.com",
    packages=find_packages(),
    install_requires=[
        "antlr4-tools>=0.2.1",
        "antlr4-python3-runtime>=4.13.2",
    ],
    entry_points={
        'console_scripts': [
            'baker=baker.main:main',
        ],
    },
    cmdclass={
        'generate_parser': GenerateAntlrParser,
        'build_py': BuildPyCommand,
        'develop': DevelopCommand,
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
    ],
    python_requires=">=3.8",
)
