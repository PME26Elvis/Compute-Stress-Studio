# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller onedir build for the CuPy-only portable GPU stress app."""

from pathlib import Path
import site

from PyInstaller.building.datastruct import Tree
from PyInstaller.utils.hooks import collect_all, copy_metadata

project_root = Path(SPECPATH).parent

cupy_datas, cupy_binaries, cupy_hidden = collect_all("cupy")
backend_datas, backend_binaries, backend_hidden = collect_all("cupy_backends")

datas = cupy_datas + backend_datas
binaries = cupy_binaries + backend_binaries
hiddenimports = sorted(set(cupy_hidden + backend_hidden + ["pynvml"]))

for distribution in ("cupy-cuda12x", "nvidia-ml-py"):
    try:
        datas += copy_metadata(distribution)
    except Exception:
        pass

# CUDA component wheels install their DLL/SO files under the nvidia namespace.
# Copy the whole namespace so the frozen app only needs a compatible NVIDIA
# display driver, not Python, pip, or a system-wide CUDA Toolkit.
for site_root in site.getsitepackages():
    nvidia_root = Path(site_root) / "nvidia"
    if nvidia_root.is_dir():
        datas += Tree(str(nvidia_root), prefix="nvidia")

portable_readme = project_root / "packaging" / "PORTABLE_README.txt"
if portable_readme.exists():
    datas.append((str(portable_readme), "."))

a = Analysis(
    [str(project_root / "gpu_stress_portable.py")],
    pathex=[str(project_root)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["torch", "numba", "PyQt5", "pyqtgraph", "scipy"],
    noarchive=False,
    optimize=1,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="GPU-Stress-Portable",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="GPU-Stress-Portable",
)
