@echo off
echo === GUI / notification-area process ===
tasklist /FI "IMAGENAME eq GPU-Stress-JUCE.exe"
echo.
echo === No-window background process ===
tasklist /FI "IMAGENAME eq GPU-Stress-JUCE-Background.exe"
echo.
echo === CLI process ===
tasklist /FI "IMAGENAME eq GPU-Stress-JUCE-CLI.exe"
echo.
echo Run your preferred GPU monitoring tool separately when needed.
pause
