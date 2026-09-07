"""Run tests for the sdcc `dir_listing` example.

The example lists the host filesystem disk (H:), which the harness roots on a
host directory, so the test controls the content and checks the listing.
"""
from pathlib import Path

from helpers import ZealEmulator

EXAMPLE_DIR = Path(__file__).resolve().parent


def test_run(tmp_path):
    # Entries the program should list on H:.
    (tmp_path / "hello.txt").write_text("hello\n")
    (tmp_path / "world.txt").write_text("world\n")
    (tmp_path / "docs").mkdir()

    with ZealEmulator(EXAMPLE_DIR, hostfs=tmp_path) as dut:
        # The listing order on the host filesystem is not deterministic, so
        # wait for the program to finish and check each entry is present.
        dut.expect_exact("Program finished")
        listing = dut.child.before
        for name in ("hello.txt", "world.txt", "docs/"):
            assert name in listing, f"'{name}' missing from listing:\n{listing}"
