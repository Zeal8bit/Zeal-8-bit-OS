from pathlib import Path
from helpers import ZealEmulator

EXAMPLE_DIR = Path(__file__).resolve().parent


def test_run():
    build_dir = EXAMPLE_DIR / "build"
    with ZealEmulator(
        EXAMPLE_DIR,
        binary=build_dir / "parent.bin",
        hostfs=build_dir,
    ) as dut:
        dut.expect_exact("I am the parent")
        dut.expect_exact("I am the child")
        dut.expect(r"Child returned: 42")
        dut.expect_exact("I am still the parent")
