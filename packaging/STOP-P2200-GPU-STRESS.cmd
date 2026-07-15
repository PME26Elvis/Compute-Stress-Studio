@echo off
cd /d "%~dp0"
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
if exist "P2200-Runs\gpu-stress-p2200.pid" del /Q "P2200-Runs\gpu-stress-p2200.pid"
echo.
echo P2200 GPU stress process stop command completed.
pause
