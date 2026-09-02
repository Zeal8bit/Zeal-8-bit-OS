"""Run tests for the z88dk-z80asm `echo` example."""
from pathlib import Path

from helpers import ZealEmulator

EXAMPLE_DIR = Path(__file__).resolve().parent


def test_run():
    with ZealEmulator(EXAMPLE_DIR, debug_mode=True) as dut:
        dut.run_ms(50)
        dut.expect_exact("Type your name: ")
        dut.tap_keys(['b', 'o', 'b', 'ENTER'])
        dut.run_ms(50)
        dut.expect(r"Hello bob")
