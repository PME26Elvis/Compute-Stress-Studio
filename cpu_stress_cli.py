#!/usr/bin/env python3
"""Standalone command-line CPU stress-test runner.

This module intentionally contains all runtime logic needed for CLI stress tests
and does not import the Qt application entry points.
"""

from __future__ import annotations

import argparse
import math
import multiprocessing
import os
import signal
import sys
import time
from typing import Iterable

try:
    import psutil
except Exception:  # pragma: no cover - optional dependency
    psutil = None


PERIOD = 0.05


def _logical_cpu_count() -> int:
    """Return logical CPU count using psutil when available, else os.cpu_count."""
    if psutil is not None:
        try:
            return psutil.cpu_count(logical=True) or 1
        except Exception:
            pass
    return os.cpu_count() or 1


def _pin_to_core(core_id: int) -> None:
    """Best-effort pinning of the current process to one logical CPU core."""
    if psutil is None:
        return
    try:
        cores = _logical_cpu_count()
        core = max(0, min(core_id, cores - 1))
        psutil.Process(os.getpid()).cpu_affinity([core])
    except Exception:
        pass


def cpu_stress_worker(shared_load_ratio: multiprocessing.Value, core_id: int = -1, pin_affinity: bool = True) -> None:
    """Generate adjustable CPU load using a shared double ratio from 0.0 to 1.0."""
    if pin_affinity and core_id >= 0:
        _pin_to_core(core_id)

    x = 1.000001
    while True:
        ratio = shared_load_ratio.value
        if ratio < 0.0:
            ratio = 0.0
        elif ratio > 1.0:
            ratio = 1.0

        work_time = PERIOD * ratio
        sleep_time = PERIOD - work_time
        start = time.perf_counter()

        if work_time > 0:
            while (time.perf_counter() - start) < work_time:
                x = x * 1.000001 + 1.0
                if x > 1e6:
                    x = math.fmod(x, 1.0)

        if sleep_time > 0:
            remain = PERIOD - (time.perf_counter() - start)
            if remain > 0:
                time.sleep(remain)


def _percent_to_ratio(value: float) -> float:
    return max(0.0, min(float(value), 100.0)) / 100.0


def _positive_float(value: str) -> float:
    parsed = float(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than 0")
    return parsed


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than 0")
    return parsed


def _percent(value: str) -> float:
    parsed = float(value)
    if parsed < 0 or parsed > 100:
        raise argparse.ArgumentTypeError("must be between 0 and 100")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run a standalone CPU stress test without the PyQt application.")
    parser.add_argument("--profile", choices=("constant", "pulsed", "ramp"), default="constant")
    parser.add_argument("--duration", type=_positive_float, required=True, metavar="SECONDS")
    parser.add_argument("--load", type=_percent, default=100.0, metavar="PERCENT", help="constant-mode target load")
    parser.add_argument("--high-load", type=_percent, default=100.0, metavar="PERCENT")
    parser.add_argument("--low-load", type=_percent, default=0.0, metavar="PERCENT")
    parser.add_argument("--on-time", type=_positive_float, default=1.0, metavar="SECONDS")
    parser.add_argument("--off-time", type=_positive_float, default=1.0, metavar="SECONDS")
    parser.add_argument("--start-load", type=_percent, default=0.0, metavar="PERCENT")
    parser.add_argument("--end-load", type=_percent, default=100.0, metavar="PERCENT")
    parser.add_argument("--workers", type=_positive_int, default=_logical_cpu_count(), metavar="N")
    parser.add_argument("--no-affinity", action="store_true", help="disable per-core CPU affinity")
    parser.add_argument("--status-interval", type=_positive_float, default=1.0, metavar="SECONDS")
    return parser


def initial_ratio(args: argparse.Namespace) -> float:
    if args.profile == "constant":
        return _percent_to_ratio(args.load)
    if args.profile == "pulsed":
        return _percent_to_ratio(args.high_load)
    return _percent_to_ratio(args.start_load)


def update_load_profile(args: argparse.Namespace, elapsed: float, shared_load_ratio: multiprocessing.Value) -> None:
    if args.profile == "pulsed":
        cycle_time = args.on_time + args.off_time
        position_in_cycle = elapsed % cycle_time
        shared_load_ratio.value = _percent_to_ratio(args.high_load if position_in_cycle < args.on_time else args.low_load)
    elif args.profile == "ramp":
        progress = min(elapsed / args.duration, 1.0)
        start = _percent_to_ratio(args.start_load)
        end = _percent_to_ratio(args.end_load)
        shared_load_ratio.value = start + (end - start) * progress


def start_workers(shared_load_ratio: multiprocessing.Value, workers: int, pin_affinity: bool) -> list[multiprocessing.Process]:
    processes: list[multiprocessing.Process] = []
    cpu_count = _logical_cpu_count()
    for worker_id in range(workers):
        core_id = worker_id % cpu_count
        process = multiprocessing.Process(
            target=cpu_stress_worker,
            args=(shared_load_ratio, core_id, pin_affinity),
            daemon=True,
        )
        process.start()
        processes.append(process)
    return processes


def stop_workers(processes: Iterable[multiprocessing.Process]) -> None:
    process_list = list(processes)
    for process in process_list:
        try:
            if process.is_alive():
                process.terminate()
        except Exception:
            pass
    for process in process_list:
        try:
            process.join(timeout=1.0)
        except Exception:
            pass


def _format_status(elapsed: float, target_percent: float, workers: int) -> str:
    status = f"elapsed={elapsed:6.1f}s target={target_percent:6.1f}% workers={workers}"
    if psutil is not None:
        try:
            status += f" cpu={psutil.cpu_percent(interval=None):5.1f}%"
        except Exception:
            pass
    return status


def run(args: argparse.Namespace) -> int:
    multiprocessing.freeze_support()
    shared_load_ratio = multiprocessing.Value("d", initial_ratio(args))
    processes: list[multiprocessing.Process] = []
    interrupted = False

    def _handle_signal(signum, _frame):
        raise KeyboardInterrupt

    previous_sigterm = signal.signal(signal.SIGTERM, _handle_signal)
    try:
        if psutil is not None:
            psutil.cpu_percent(interval=None)
        processes = start_workers(shared_load_ratio, args.workers, not args.no_affinity)
        start_time = time.time()
        next_status = 0.0
        print(
            f"started profile={args.profile} duration={args.duration:g}s workers={args.workers} "
            f"affinity={'off' if args.no_affinity else 'on'}",
            flush=True,
        )

        while True:
            elapsed = time.time() - start_time
            if elapsed >= args.duration:
                update_load_profile(args, args.duration, shared_load_ratio)
                break

            update_load_profile(args, elapsed, shared_load_ratio)
            if elapsed >= next_status:
                print(_format_status(elapsed, shared_load_ratio.value * 100.0, args.workers), flush=True)
                next_status += args.status_interval

            time.sleep(min(0.25, args.status_interval, max(args.duration - elapsed, 0.01)))

        print(_format_status(args.duration, shared_load_ratio.value * 100.0, args.workers), flush=True)
        return 0
    except KeyboardInterrupt:
        interrupted = True
        print("interrupted; stopping workers", file=sys.stderr, flush=True)
        return 130
    finally:
        stop_workers(processes)
        signal.signal(signal.SIGTERM, previous_sigterm)
        if not interrupted:
            print("stopped", flush=True)


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
