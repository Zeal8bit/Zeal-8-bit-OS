"""Run tests for the sdcc `raw_keyboard` example."""
from pathlib import Path

from helpers import ZealEmulator

EXAMPLE_DIR = Path(__file__).resolve().parent


def test_run():
    with ZealEmulator(EXAMPLE_DIR, debug_mode=True) as dut:
        dut.run_ms(50)
        dut.expect_exact("Raw keyboard mode")
        dut.tap_keys(['a', 'b', 'c'])
        dut.run_ms(50)
        dut.expect_exact("abc")
