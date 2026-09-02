"""The example lists the host filesystem (H:), which the test roots on a
temporary directory so it controls what gets listed."""
from pathlib import Path

from helpers import ZealEmulator

EXAMPLE_DIR = Path(__file__).resolve().parent


def test_run(tmp_path):
    # Entries the program should list on H:
    (tmp_path / "hello.txt").write_text("hello\n")
    (tmp_path / "world.txt").write_text("world\n")
    (tmp_path / "docs").mkdir()

    with ZealEmulator(EXAMPLE_DIR, hostfs=tmp_path) as dut:
        # The listing order is not deterministic, wait for the program to end
        # and check that each entry is present.
        dut.expect_exact("Program finished")
        listing = dut.child.before
        for name in ("hello.txt", "world.txt", "docs/"):
            assert name in listing, f"'{name}' missing from listing:\n{listing}"
