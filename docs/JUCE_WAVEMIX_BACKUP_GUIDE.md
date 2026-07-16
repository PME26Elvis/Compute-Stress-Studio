# Quadro P2200 JUCE WaveMix 靜默備用版操作指南

這是既有 Python／CuPy 版本之外的獨立備用實作，專門保留給以下環境：

- Windows 10 Pro
- NVIDIA Quadro P2200 5 GB
- NVIDIA 驅動 561.17
- 96 小時長跑需求
- 87% 目標負載
- 希望同時具備 GUI、通知區常駐、CLI 與完全無視窗背景模式

## 這個版本和原版有何不同

| 項目 | 原 Python 版 | JUCE WaveMix 備用版 |
| --- | --- | --- |
| 語言／介面 | Python CLI | C++20 + JUCE GUI/CLI |
| GPU 工作負載 | CuPy/PyTorch cuBLAS GEMM | 自訂 CUDA WaveMix kernel |
| 運算內容 | 矩陣乘法 | FP32 FMA、整數 scrambling、shared/global memory 混合 |
| 負載控制 | NVML utilization PI 回授 | 依實測 active time 的固定 duty window |
| kernel 長度 | 框架決定 | 啟動時校準到約 8 ms |
| 監控與輸出 | 可顯示 telemetry 並寫入結果 | 純壓測；不監控、不寫檔、正常執行完全靜默 |

因此兩個版本不只是換 GUI；底層壓測方法與控制策略也不同。

## 靜默模式的具體定義

JUCE 備用版現在只負責建立 GPU workload：

- 不再呼叫 `nvidia-smi`，因此不會每秒啟動監控子程序或閃出終端視窗。
- 正常 CLI 執行不會週期性輸出文字。
- 不建立 `JUCE-Backup-Runs`。
- 不寫 log、CSV、startup error log 或 PID file。
- 不再內建溫度監控與 thermal pause。
- GUI 只顯示引擎本身已知的狀態、時間、kernel 校準與 duty active/idle，不顯示 GPU 溫度、功耗或 utilization。

`--help` 仍會刻意輸出說明；GUI 的錯誤對話框也會保留，因為這兩者是使用者主動要求或必要的啟動錯誤提示，不屬於週期性背景輸出。

### 關於移除溫度保護

NVIDIA GPU 通常有驅動、韌體、動態降頻與硬體保護機制，但這不代表任何散熱故障情境都能完全忽略。這個版本依你的需求移除應用程式層的溫度牆；請用你原本的監控工具觀察溫度、風扇、時脈與功耗，第一次仍建議先短測。

## Release 下載內容

Windows ZIP 內包含：

```text
GPU-Stress-JUCE.exe
GPU-Stress-JUCE-Background.exe
GPU-Stress-JUCE-CLI.exe
START-JUCE-BACKUP-GUI.cmd
START-JUCE-BACKUP-BACKGROUND.cmd
STOP-JUCE-BACKUP.cmd
CHECK-JUCE-BACKUP.cmd
JUCE_WAVEMIX_BACKUP_GUIDE.md
THIRD_PARTY_NOTICES.md
JUCE-LICENSE.md
```

請完整解壓 ZIP，不要只抽出單一 EXE。

## GUI 與 Windows 通知區

直接雙擊：

```text
GPU-Stress-JUCE.exe
```

GUI 可調整：

- 執行時間
- 目標 duty load
- WaveMix VRAM budget
- synthetic dry-run

預設值為：

```text
Duration = 96 hours
Load = 87%
VRAM = 192 MiB
```

### 隱藏到背景

GUI 內有：

```text
Hide to background
```

按下後，視窗會從工作列消失，程式保留在 Windows 通知區，也就是工作列右下角按箭頭後看到的 icon 區域。關閉 GUI 視窗或按最小化，也會改成隱藏到通知區，而不是終止壓測。

通知區 icon 操作：

- 雙擊 icon：還原 GUI。
- 左鍵點擊：還原 GUI。
- 右鍵 `Show window`：顯示 GUI。
- 右鍵 `Hide to background`：隱藏 GUI。
- 右鍵 `Stop stress`：停止目前壓測，但保留程式與 tray icon。
- 右鍵 `Exit`：停止壓測並完整結束應用程式。

Windows 可能依系統偏好把 icon 收在箭頭展開區，而不是直接顯示在工作列上。

## 完全無視窗背景模式

直接雙擊：

```text
GPU-Stress-JUCE-Background.exe
```

或：

```text
START-JUCE-BACKUP-BACKGROUND.cmd
```

這個 EXE 使用 Windows GUI subsystem，不建立 GUI 視窗或 tray icon，直接使用個人預設：

```text
--duration 345600 --load 87
```

背景版本用 inter-process lock 阻止重複啟動第二份。

## 手動停止

### GUI／tray 版本

最簡單的方法是右鍵通知區 icon，選擇：

```text
Stop stress
```

需要連程式一起關閉則選：

```text
Exit
```

也可在工作管理員中結束 `GPU-Stress-JUCE.exe`。

### 完全無視窗背景版本

可直接複製貼到 Windows CMD：

```cmd
taskkill /F /T /IM GPU-Stress-JUCE-Background.exe
```

或雙擊：

```text
STOP-JUCE-BACKUP.cmd
```

若你是用 CLI 執行：

```cmd
taskkill /F /T /IM GPU-Stress-JUCE-CLI.exe
```

若要強制關閉 GUI 版本：

```cmd
taskkill /F /T /IM GPU-Stress-JUCE.exe
```

## 確認是否正在執行

```cmd
tasklist /FI "IMAGENAME eq GPU-Stress-JUCE-Background.exe"
tasklist /FI "IMAGENAME eq GPU-Stress-JUCE.exe"
```

也可以雙擊：

```text
CHECK-JUCE-BACKUP.cmd
```

GPU 狀態請使用你自己的監控工具，或手動執行：

```cmd
nvidia-smi
```

程式本身不會再自動執行這個命令。

## CLI 模式

查看說明：

```cmd
GPU-Stress-JUCE-CLI.exe --help
```

不帶參數：

```cmd
GPU-Stress-JUCE-CLI.exe
```

等同：

```cmd
GPU-Stress-JUCE-CLI.exe --duration 345600 --load 87
```

自訂 2 小時、75%：

```cmd
GPU-Stress-JUCE-CLI.exe --duration 7200 --load 75
```

短時間驗證：

```cmd
GPU-Stress-JUCE-CLI.exe --duration 30 --load 25
GPU-Stress-JUCE-CLI.exe --duration 1800 --load 87
```

package self-test：

```cmd
GPU-Stress-JUCE-CLI.exe --self-test
```

成功時沒有文字輸出，以 exit code `0` 表示通過。

不碰 GPU 的完整流程 dry-run：

```cmd
GPU-Stress-JUCE-CLI.exe --dry-run --duration 5 --load 87
```

正常壓測與 dry-run 都不建立任何輸出檔案。

## Quadro P2200 專用注意事項

- P2200 是 Pascal 架構，Release 明確編譯 `sm_61`。
- 預設 192 MiB VRAM 遠低於 5 GB，並保留空間給驅動與顯示用途。
- WaveMix 使用短 kernel，而不是 persistent kernel，目的是降低 Windows WDDM TDR 風險。
- `87%` 代表每個 200 ms window 約要求 174 ms GPU active time；它不是保證外部監控永遠顯示 87%，也不代表 87% TDP。
- 應用程式不再監控溫度；第一次使用建議先跑 30 秒 25%，再跑 30 分鐘 87%，確認風扇、供電與穩定性後才啟動 96 小時。

## Linux GUI / AppImage

Linux Release 會提供 tar.gz 與 AppImage：

```bash
chmod +x GPU-Stress-JUCE-Backup-x86_64.AppImage
./GPU-Stress-JUCE-Backup-x86_64.AppImage
```

背景模式：

```bash
./GPU-Stress-JUCE-Backup-x86_64.AppImage --background
```

Linux tray 行為取決於桌面環境是否提供 system tray host。AppImage 不會內含或替換 NVIDIA 主機驅動。

## 測試範圍

CI 必須全部通過後才發布：

1. Host-only C++ unit tests
2. 96h／87% 預設與參數 parser
3. 已移除的 telemetry／temperature／output options 必須被拒絕
4. duty scheduler 與 overshoot
5. engine timed completion、stop request 與 error path
6. CUDA `sm_61` kernel 編譯
7. CLI self-test 必須完全無 stdout/stderr
8. CLI dry-run 必須完全無 stdout/stderr 且不建立檔案
9. Windows GUI tray hide／restore lifecycle smoke test
10. Windows no-window background dry-run 且不建立檔案
11. Linux GUI tray lifecycle under Xvfb
12. Linux background dry-run 且不建立檔案
13. AppImage 建立與 extract-and-run smoke test

GitHub runner 沒有實體 Quadro P2200，因此真正 GPU kernel 執行、溫度與功耗曲線仍需在你的 P2200 主機做最後 hardware smoke test。
