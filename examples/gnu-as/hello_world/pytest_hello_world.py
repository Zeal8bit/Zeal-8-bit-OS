"""Run tests for the gnu-as `hello_world` example."""
from pathlib import Path

from helpers import ZealEmulator

EXAMPLE_DIR = Path(__file__).resolve().parent


def test_run():
    with ZealEmulator(EXAMPLE_DIR) as dut:
        dut.expect_exact("Hello World!")
