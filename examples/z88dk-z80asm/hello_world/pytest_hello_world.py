"""Run tests for the z88dk-z80asm `hello_world` example."""
from pathlib import Path

from helpers import ZealEmulator

EXAMPLE_DIR = Path(__file__).resolve().parent


def test_run():
    with ZealEmulator(EXAMPLE_DIR) as dut:
        dut.expect_exact("Hello World!")
