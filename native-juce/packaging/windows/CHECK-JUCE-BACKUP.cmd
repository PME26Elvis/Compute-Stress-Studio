@echo off
echo === Background process ===
tasklist /FI "IMAGENAME eq GPU-Stress-JUCE-Background.exe"
echo.
echo === CLI process ===
tasklist /FI "IMAGENAME eq GPU-Stress-JUCE-CLI.exe"
echo.
nvidia-smi
pause
