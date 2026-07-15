# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller one-file build for the hidden Windows P2200 launcher."""

from pathlib import Path

project_root = Path(SPECPATH).parent

a = Analysis(
    [str(project_root / "gpu_stress_background.py")],
    pathex=[str(project_root)],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["cupy", "numpy", "torch", "numba", "PyQt5", "pyqtgraph"],
    noarchive=False,
    optimize=1,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="GPU-Stress-P2200-Background",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=True,
)
