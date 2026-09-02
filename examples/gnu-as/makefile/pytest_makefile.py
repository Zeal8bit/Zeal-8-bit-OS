"""Run tests for the gnu-as `makefile` example.

This example has no source of its own: it builds the `hello_world` source via
plain `make` (see the Makefile in this directory).
"""
from pathlib import Path

from helpers import ZealEmulator

EXAMPLE_DIR = Path(__file__).resolve().parent


def test_run():
    with ZealEmulator(EXAMPLE_DIR) as dut:
        dut.expect_exact("Hello World!")
