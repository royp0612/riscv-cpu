#!/usr/bin/env python3
"""
regress.py - run every testbench in tb/ and report pass/fail.

Usage (from the repo root):
    python3 scripts/regress.py            # run all testbenches
    python3 scripts/regress.py alu core   # run only tests whose name contains "alu" or "core"
    python3 scripts/regress.py -v         # also print each testbench's full output

Exit code is 0 if everything passes and 1 if anything fails, so CI can use it.
"""

import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RTL_DIR = ROOT / "rtl"
TB_DIR = ROOT / "tb"
BUILD_DIR = ROOT / "build"
TIMEOUT_S = 60

# The package must be compiled before any module that imports it.
PACKAGE = "cpu_package.sv"


def rtl_sources():
    files = sorted(RTL_DIR.glob("*.sv"))
    pkg = [f for f in files if f.name == PACKAGE]
    rest = [f for f in files if f.name != PACKAGE and f.name != "top.sv"]  # top.sv needs Vivado IP
    return pkg + rest


def run(cmd):
    """Run a command from the repo root; return (exit code, combined output)."""
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=TIMEOUT_S)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return -1, f"TIMEOUT after {TIMEOUT_S}s (testbench may be missing $finish)"


def run_test(tb_file):
    """Compile and simulate one testbench. Returns (status, seconds, output)."""
    name = tb_file.stem
    sim = BUILD_DIR / f"{name}.vvp"
    start = time.time()

    code, out = run(["iverilog", "-g2012", "-s", name, "-o", str(sim),
                     *map(str, rtl_sources()), str(tb_file)])
    if code != 0:
        return "COMPILE ERROR", time.time() - start, out

    code, out = run(["vvp", "-n", str(sim)])
    elapsed = time.time() - start

    if code == -1:
        return "TIMEOUT", elapsed, out
    if code != 0:
        return "FAIL", elapsed, out
    if "FAIL" in out.upper().replace("FAILED: 0", ""):
        return "FAIL", elapsed, out
    if "PASS" not in out.upper():
        return "NO RESULT", elapsed, out   # testbench never printed PASS
    return "PASS", elapsed, out


def main():
    ap = argparse.ArgumentParser(description="Run the RISC-V testbench regression.")
    ap.add_argument("filters", nargs="*", help="only run testbenches whose name contains one of these")
    ap.add_argument("-v", "--verbose", action="store_true", help="print full output of every test")
    args = ap.parse_args()

    tests = sorted(TB_DIR.glob("*.sv"))
    if args.filters:
        tests = [t for t in tests if any(f in t.stem for f in args.filters)]
    if not tests:
        print("No testbenches found.")
        return 1

    BUILD_DIR.mkdir(exist_ok=True)
    print(f"Running {len(tests)} testbench(es)\n")
    print(f"{'TEST':<20}{'RESULT':<16}{'TIME':>8}")
    print("-" * 44)

    failures = []
    for tb in tests:
        status, secs, out = run_test(tb)
        print(f"{tb.stem:<20}{status:<16}{secs:>7.2f}s")
        if status != "PASS":
            failures.append((tb.stem, status, out))
        elif args.verbose:
            print(out)

    print("-" * 44)
    passed = len(tests) - len(failures)
    print(f"{passed}/{len(tests)} passed")

    for name, status, out in failures:
        print(f"\n===== {name}: {status} =====")
        print(out.strip()[-3000:])  # last part of the log is where the error is

    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
