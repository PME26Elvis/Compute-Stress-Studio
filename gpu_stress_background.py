#!/usr/bin/env python3
"""No-window launcher for the user's Quadro P2200 preset.

The frozen Windows launcher starts the console worker as a detached hidden
process, records its PID, and returns immediately. The worker itself owns the
96-hour/87-percent defaults so direct command-line use behaves the same way.
"""

from __future__ import annotations

import ctypes
import os
import subprocess
import sys
import time
from pathlib import Path

DEFAULT_DURATION_SECONDS = 96 * 60 * 60
DEFAULT_LOAD_PERCENT = 87
WORKER_FILENAME = "GPU-Stress-P2200-Worker.exe"
RUN_DIRECTORY_NAME = "P2200-Runs"
PID_FILENAME = "gpu-stress-p2200.pid"
CONSOLE_LOG_FILENAME = "gpu-stress-p2200-console.log"
CSV_FILENAME = "gpu-stress-p2200.csv"


def _has_option(argv: list[str], option: str) -> bool:
    return any(value == option or value.startswith(f"{option}=") for value in argv)


def _build_worker_arguments(argv: list[str], csv_path: Path) -> list[str]:
    """Add the personal defaults only when the caller did not override them."""
    output = list(argv)
    informational = any(
        value in {"-h", "--help", "--diagnose", "--list-gpus"} for value in output
    )
    if not informational and not _has_option(output, "--duration"):
        output.extend(["--duration", str(DEFAULT_DURATION_SECONDS)])
    if (
        not informational
        and not _has_option(output, "--load")
        and not _has_option(output, "--profile")
    ):
        output.extend(["--load", str(DEFAULT_LOAD_PERCENT)])
    if not informational and not _has_option(output, "--csv"):
        output.extend(["--csv", str(csv_path)])
    return output


def _is_process_running(pid: int) -> bool:
    if pid <= 0 or os.name != "nt":
        return False
    process_query_limited_information = 0x1000
    still_active = 259
    kernel32 = ctypes.windll.kernel32
    handle = kernel32.OpenProcess(process_query_limited_information, False, pid)
    if not handle:
        return False
    try:
        exit_code = ctypes.c_ulong()
        if not kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
            return False
        return exit_code.value == still_active
    finally:
        kernel32.CloseHandle(handle)


def _read_existing_pid(pid_path: Path) -> int | None:
    try:
        value = int(pid_path.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None
    return value if _is_process_running(value) else None


def _append_launcher_log(log_path: Path, message: str) -> None:
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with log_path.open("a", encoding="utf-8") as stream:
        stream.write(f"[{timestamp}] launcher: {message}\n")


def launch(argv: list[str] | None = None) -> int:
    if os.name != "nt":
        raise RuntimeError("The hidden background launcher is Windows-only")

    supplied = list(sys.argv[1:] if argv is None else argv)
    app_directory = Path(sys.executable).resolve().parent
    worker_path = app_directory / WORKER_FILENAME
    run_directory = app_directory / RUN_DIRECTORY_NAME
    run_directory.mkdir(parents=True, exist_ok=True)

    pid_path = run_directory / PID_FILENAME
    log_path = run_directory / CONSOLE_LOG_FILENAME
    csv_path = run_directory / CSV_FILENAME

    existing_pid = _read_existing_pid(pid_path)
    if existing_pid is not None:
        _append_launcher_log(log_path, f"already running with PID {existing_pid}")
        return 0

    if not worker_path.is_file():
        _append_launcher_log(log_path, f"worker not found: {worker_path}")
        return 2

    arguments = [str(worker_path), *_build_worker_arguments(supplied, csv_path)]
    creation_flags = (
        subprocess.CREATE_NO_WINDOW
        | subprocess.DETACHED_PROCESS
        | subprocess.CREATE_NEW_PROCESS_GROUP
    )
    startup_info = subprocess.STARTUPINFO()
    startup_info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup_info.wShowWindow = subprocess.SW_HIDE

    with log_path.open("a", encoding="utf-8") as log_stream:
        process = subprocess.Popen(
            arguments,
            cwd=str(app_directory),
            stdin=subprocess.DEVNULL,
            stdout=log_stream,
            stderr=subprocess.STDOUT,
            close_fds=True,
            creationflags=creation_flags,
            startupinfo=startup_info,
        )

    pid_path.write_text(f"{process.pid}\n", encoding="utf-8")
    _append_launcher_log(
        log_path,
        f"started PID {process.pid}; duration={DEFAULT_DURATION_SECONDS}s load={DEFAULT_LOAD_PERCENT}%",
    )
    return 0


def main() -> int:
    try:
        return launch()
    except Exception as exc:
        try:
            app_directory = Path(sys.executable).resolve().parent
            run_directory = app_directory / RUN_DIRECTORY_NAME
            run_directory.mkdir(parents=True, exist_ok=True)
            _append_launcher_log(run_directory / CONSOLE_LOG_FILENAME, f"launch failed: {exc}")
        except Exception:
            pass
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
