"""Shared helpers for the per-example test files (examples/**/pytest_*.py).

Each example declares its own expectations in a small pytest_<name>.py file;
this module provides the actual build/run logic so it is not duplicated.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

# Root of the Zeal 8-bit OS repository
REPO_ROOT = Path(__file__).resolve().parent.parent

# Exact binary name per toolchaun. Must be present in PATH to build it.
TOOLCHAIN_TOOL = {
    "gnu-as": "z80-elf-as",
    "sdcc": "sdcc",
    "z88dk-z80asm": "z88dk-z80asm",
}


def toolchain_of(example_dir):
    """Toolchain name (parent directory name) of the given example directory."""
    return Path(example_dir).resolve().parent.name


def zos_env():
    """Environment for build commands, with ZOS_PATH set."""
    env = dict(os.environ)
    env["ZOS_PATH"] = os.environ.get("ZOS_PATH", str(REPO_ROOT))
    return env


def _run(cmd, cwd, env):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)


def _describe(example_dir, step, result):
    return (
        f"{step} failed for {example_dir}\n"
        f"--- stdout ---\n{result.stdout}\n--- stderr ---\n{result.stderr}"
    )


def find_binaries(example_dir):
    """Raw binaries produced by the example (root dir, bin/, build/).

    CMake's internal configure artifacts (build/CMakeFiles/...) are excluded,
    otherwise a CMakeDetermineCompilerABI_*.bin can shadow the real output.
    """
    candidates = []
    for pattern in ("*.bin", "bin/*.bin", "build/**/*.bin"):
        candidates.extend(Path(example_dir).glob(pattern))
    return sorted(
        p for p in candidates if p.is_file() and "CMakeFiles" not in p.parts
    )


def require_toolchain(example_dir):
    """Skip if the toolchain needed by the example is not installed."""
    tool = TOOLCHAIN_TOOL.get(toolchain_of(example_dir))
    if tool is None or shutil.which(tool) is None:
        pytest.skip(f"toolchain binary '{tool}' not found in PATH")


def build_example(example_dir):
    """Build the example (make if it has a Makefile, else CMake) and check a
    raw binary is produced."""
    require_toolchain(example_dir)
    example_dir = Path(example_dir)
    print(f"Building {example_dir.relative_to(REPO_ROOT)}", flush=True)
    env = zos_env()

    if (example_dir / "Makefile").exists():
        result = _run(["make"], example_dir, env)
        assert result.returncode == 0, _describe(example_dir, "make", result)
    else:
        # Always configure from scratch: a stale build/ cache (e.g. configured
        # under a different /src mount or host) makes CMake reject the source.
        build_dir = example_dir / "build"
        if build_dir.exists():
            shutil.rmtree(build_dir)
        result = _run(["cmake", "-S", ".", "-B", "build"], example_dir, env)
        assert result.returncode == 0, _describe(
            example_dir, "cmake configure", result
        )
        result = _run(["cmake", "--build", "build"], example_dir, env)
        assert result.returncode == 0, _describe(example_dir, "cmake build", result)

    assert find_binaries(example_dir), (
        f"no .bin binary produced for {example_dir}"
    )


class ZealEmulator:
    """Device-Under-Test: one built example running on the emulator.

    The example must be built first (see `tests/build_all.py`). The emulator
    binary comes from the ZOS_EMULATOR environment variable and the OS ROM
    image (passed via `--rom`) comes from the ZOS_IMG environment variable.

    The emulator runs in console+debug mode (`--console --debug`): it reads
    control commands from stdin and prints a `debug> ` prompt. On startup the
    machine is run up to a breakpoint at 0x4000 (the program entry point) and
    then handed over to the test:

        <ZOS_EMULATOR> --console --debug --rom <ZOS_IMG> -u <example.bin>

    Use it as a context manager: entering spawns the emulator and runs it up
    to the program entry, leaving closes it (even on assertion failure):

        with ZealEmulator(EXAMPLE_DIR) as dut:
            dut.run_ms(50)   # let the program print its prompt
            dut.expect_exact("Type your name: ")
            dut.tap("B")
            dut.tap("o")
            dut.tap("b")
            dut.run_ms(50)
            dut.expect(r"Hello Bob")
            dut.quit()
    """

    # Filled in at spawn time from pexpect (avoid a hard import at module load)
    EOF = None
    TIMEOUT = None

    # Address where the OS loads and runs the example program by default
    ENTRY_ADDR = 0x4000

    # How long (ms) to run the program when not in debug mode, so that its
    # output is produced before the test starts expecting.
    WAIT_MS = 1000

    # Default timeout (seconds) for the pexpect waits (spawn, expects, runs).
    DEFAULT_TIMEOUT = 10

    def __init__(self, example_dir, debug_mode=False, entry_addr=ENTRY_ADDR,
                 wait_ms=WAIT_MS, timeout=DEFAULT_TIMEOUT, binary=None,
                 hostfs=None):
        self.dir = Path(example_dir)
        self.toolchain = self.dir.parent.name
        binaries = find_binaries(self.dir)
        # `binary` overrides the auto-detected one (examples producing several
        # .bin files pick which one is the init program via `-u`).
        self.binary = Path(binary) if binary is not None else (
            binaries[0] if binaries else None)
        # `hostfs` roots the emulator's host filesystem (H:) on the given dir.
        self.hostfs = Path(hostfs) if hostfs is not None else None
        self.entry_addr = entry_addr
        self.debug_mode = debug_mode
        self.wait_ms = wait_ms
        self.timeout = timeout
        self.child = None
        self._logfile = None

    # -- lifecycle ---------------------------------------------------------

    def __enter__(self):
        self.spawn()
        return self

    def __exit__(self, *exc):
        self.close()

    def spawn(self, timeout=None):
        """Start the emulator with the example binary on a pseudo-terminal.

        `timeout` overrides the instance default (self.timeout) when given.
        """
        # Imported lazily: this module is also used for build-only tasks (in
        # the ZDE container) where pexpect is not installed.
        import shlex
        import pexpect

        timeout = self.timeout if timeout is None else timeout
        self.EOF = pexpect.EOF
        self.TIMEOUT = pexpect.TIMEOUT

        if self.binary is None:
            raise RuntimeError(
                f"no built binary for {self.dir}; "
                "run 'pytest tests/build_all.py' first"
            )
        emulator = os.environ.get("ZOS_EMULATOR", "").strip()
        if not emulator:
            pytest.skip("set ZOS_EMULATOR to run examples (e.g. ZOS_EMULATOR=zeal-native)")
        rom = os.environ.get("ZOS_IMG", "").strip()
        if not rom:
            pytest.skip("set ZOS_IMG to the OS image path (used with --rom)")
        argv = [
            *shlex.split(emulator),
            "--headless",
            "--console",
            *(["-H", str(self.hostfs)] if self.hostfs is not None else []),
            *(["--debug"] if self.debug_mode else []),
            "--rom",
            rom,
            "-u",
            str(self.binary),
        ]
        # Optional emulator output logging for debugging. Set ZOS_LOG to `-`
        # (or `1`) to echo to stdout, or to a file path to log to that file.
        logfile = sys.stdout
        zos_log = os.environ.get("ZOS_LOG", "").strip()
        if zos_log:
            logfile = open(zos_log, "w", encoding="utf-8")
        self.child = pexpect.spawn(
            argv[0],
            argv[1:],
            encoding="utf-8",
            timeout=timeout,
            logfile=logfile,
        )
        self._logfile = logfile
        if self.debug_mode:
            # Debug mode: pause at the program entry point so the test can
            # drive the machine (input via tap/press) and expect interactively.
            self.expect_exact("debug> ", timeout=timeout)
            self.sendline(f"bp {self.entry_addr:#x}")
            self.expect_exact("Breakpoint set", timeout=timeout)
            self.sendline("continue")
            self.expect(rf"Paused @ {self.entry_addr:#x}", timeout=timeout)
        else:
            # No debugger: launch the program and let it run for wait_ms so
            # its output is produced. Do not wait for the next `debug> `
            # prompt here: that would consume the program output before the
            # test gets a chance to expect it.
            self.expect_exact("debug> ", timeout=timeout)
            self.sendline(f"run {self.wait_ms * 10000}")

    def close(self):
        """Close the emulator process, killing it if still running."""
        if self.child is not None:
            if self.child.isalive():
                self.child.close(force=True)
            self.child = None
        if self._logfile is not None and self._logfile is not sys.stdout:
            self._logfile.close()
            self._logfile = None

    # -- interaction -------------------------------------------------------

    def expect(self, pattern, timeout=-1):
        """Wait for a regex (or ZealEmulator.EOF/TIMEOUT) on the output."""
        return self.child.expect(pattern, timeout=timeout)

    def expect_exact(self, string, timeout=-1):
        """Wait for a literal string on the emulator output."""
        return self.child.expect_exact(string, timeout=timeout)

    def expect_any(self, patterns, timeout=-1):
        """Wait for any of several patterns, return the matching index."""
        return self.child.expect(patterns, timeout=timeout)

    def send(self, data):
        """Send data to the emulator's stdin."""
        return self.child.send(data)

    def sendline(self, data=""):
        """Send a line (data + newline) to the emulator's stdin."""
        return self.child.sendline(data)

    def run_tstates(self, tstates, timeout=10):
        """Advance the emulation by an exact number of Z80 T-states.

        Waits for the next `debug> ` prompt, i.e. until the run completed.
        """
        self.sendline(f"run {tstates}")
        self.expect_exact("debug> ", timeout=timeout)

    def run_ms(self, ms, timeout=10):
        """Advance the emulation for a wall-clock duration.

        The emulator's CPU runs at 10 MHz: 1 ms == 10,000 T-states.
        """
        self.run_tstates(ms * 10000, timeout=timeout)

    def press(self, key):
        """Press and hold a keyboard key."""
        self.sendline(f"press {key}")

    def release(self, key):
        """Release a keyboard key."""
        self.sendline(f"release {key}")

    def tap(self, key):
        """Press then release a keyboard key."""
        self.sendline(f"tap {key}")

    def tap_keys(self, keys):
        """Press then release keyboard keys."""
        for k in keys:
            self.sendline(f"tap {k}")

    def tapline(self, chars):
        for c in chars:
            self.sendline(f"tap {c}")            

    def quit(self):
        """Ask the emulator to exit cleanly."""
        self.sendline("quit")

    def run(self, stdin=None, timeout=30):
        """One-shot: feed optional stdin, wait for exit, return the output."""
        self.spawn(timeout=timeout)
        try:
            if stdin is not None:
                self.send(stdin)
            self.expect(ZealEmulator.EOF, timeout=timeout)
            assert self.child.exitstatus == 0, (
                f"emulator exited with {self.child.exitstatus} for {self.dir}"
            )
            return self.child.before
        finally:
            self.close()
