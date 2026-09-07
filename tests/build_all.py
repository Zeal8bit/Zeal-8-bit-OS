"""Build every example in a single test, before the per-example run tests.

Run it first to build everything:

    pytest tests/build_all.py -v
    pytest -k run

The per-example pytest_*.py files also define their own `test_build`; this
module is a convenience to build everything up front (e.g. in CI) in one pass.
Examples whose toolchain is not installed are skipped (see
helpers.require_toolchain).
"""

from pathlib import Path

from helpers import build_example

REPO_ROOT = Path(__file__).resolve().parent.parent


def discover_example_dirs():
    """Yield every example directory (one having a Makefile or a CMakeLists.txt)."""
    root = REPO_ROOT / "examples"
    if not root.exists():
        return
    for toolchain_dir in sorted(root.iterdir()):
        if not toolchain_dir.is_dir() or toolchain_dir.name.startswith("."):
            continue
        for example_dir in sorted(toolchain_dir.iterdir()):
            if not example_dir.is_dir():
                continue
            if (example_dir / "Makefile").exists() or (
                example_dir / "CMakeLists.txt"
            ).exists():
                yield example_dir


def test_build_all():
    """Build every example and check a raw binary is produced for each."""
    built = 0
    for example_dir in discover_example_dirs():
        build_example(example_dir)
        built += 1
    print(f"Built {built} examples")
