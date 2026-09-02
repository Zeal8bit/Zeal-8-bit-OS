# Example tests for Zeal 8-bit OS

Every example has its own test file, `pytest_<example>.py`, located directly inside its directory (for example `examples/sdcc/mouse/pytest_mouse.py`).

Each test file defines a single test, `test_run`, driving the example through the Zeal Native emulator

## Prerequisites

- `python3` with `pytest` (`pip install -r tests/requirements.txt`)
- At least one toolchain available in `PATH`:
  - `gnu-as`: `z80-elf-as` (binutils for z80-elf)
  - `sdcc`: `sdcc` 4.2.0+
  - `z88dk-z80asm`: `z88dk-z80asm`

  The toolchains are not needed on the host when running the suite through
  `zde` (the Zeal Dev Environment), which ships all the required build setup:
  the toolchains above plus `cmake`.
- `ZOS_PATH` pointing to the repository root (defaults to the repo layout when
  run from a checkout)
- To run the example programs, you need the following environment variables:
  - `ZOS_EMULATOR` pointing to the Zeal Native Emulator, compiled with debugger
    mode enabled
  - `ZOS_IMG` pointing to the Zeal 8-bit OS ROM image to use

## Running with `zde`

`zde` ships the required toolchains, so the whole example suite can run inside it. Please note that `zde` carries its own clone of the Zeal 8-bit OS source tree (used as `ZOS_PATH`), but that clone may be **stale** compared to the current state of this project. By overriding `ZOS_PATH` to point at the mounted repository we build against the **current revision** as the OS source.

From the repo root (the whole repository is mounted at `/src`), build every example in one pass:

```bash
zde exec bash -c "export ZOS_PATH=/src && pytest tests/build_all.py -s"
```

## Build everything first

`tests/build_all.py` builds every example in one pass:

```bash
pytest tests/build_all.py -v
```

Use it before the run tests when an emulator is configured, e.g. in CI.

## Running the tests

From the repo root or from the `examples` directory:

```bash
pytest -v
```

Toolchains that are not installed are skipped automatically.

## Filter by toolchain or example

Test ids follow the `toolchain/example` pattern, so `pytest`'s `-k` flag can be
used to select a subset:

```bash
# Only the mouse example
pytest -k "mouse"

# Only the build steps, for every example
pytest -k "build"
```
