@echo off
taskkill /F /T /IM GPU-Stress-JUCE-Background.exe >nul 2>&1
taskkill /F /T /IM GPU-Stress-JUCE-CLI.exe >nul 2>&1
echo Stop commands sent to JUCE backup background and CLI processes.
pause
