# Quadro P2200 JUCE WaveMix 備用版操作指南

這是既有 Python／CuPy 版本之外的獨立備用實作，專門保留給以下環境：

- Windows 10 Pro
- NVIDIA Quadro P2200 5 GB
- NVIDIA 驅動 561.17
- 96 小時長跑需求
- 87% 目標負載
- 希望同時具備 GUI、CLI 與完全無視窗背景模式

## 這個版本和原版有何不同

| 項目 | 原 Python 版 | JUCE WaveMix 備用版 |
| --- | --- | --- |
| 語言／介面 | Python CLI | C++20 + JUCE GUI/CLI |
| GPU 工作負載 | CuPy/PyTorch cuBLAS GEMM | 自訂 CUDA WaveMix kernel |
| 運算內容 | 矩陣乘法 | FP32 FMA、整數 scrambling、shared/global memory 混合 |
| 負載控制 | NVML utilization PI 回授 | 依實測 active time 的固定 duty window |
| kernel 長度 | 框架決定 | 啟動時校準到約 8 ms |
| 主要用途 | 一般自適應負載 | 獨立備援與交叉驗證 |

因此兩個版本不只是換 GUI；底層壓測方法與控制策略也不同。若其中一個框架、CUDA runtime 或 workload 在某張卡上表現異常，可以用另一個版本交叉驗證。

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

## GUI 模式

直接雙擊：

```text
GPU-Stress-JUCE.exe
```

GUI 可調整：

- 執行時間
- 目標 duty load
- WaveMix VRAM budget
- 溫度暫停上限
- synthetic dry-run

預設值為：

```text
Duration = 96 hours
Load = 87%
VRAM = 192 MiB
Temperature limit = 85 C
```

按下 `Start WaveMix` 後，畫面會顯示：

- 狀態與剩餘時間
- `nvidia-smi` 回報的 utilization
- 溫度
- 功耗
- VRAM
- kernel 校準時間與 iterations
- 每個 duty window 的 active/idle 時間

## 完全無視窗背景模式

直接雙擊：

```text
GPU-Stress-JUCE-Background.exe
```

或：

```text
START-JUCE-BACKUP-BACKGROUND.cmd
```

這個 EXE 使用 Windows GUI subsystem，不會開啟 CMD 視窗，也不建立 JUCE 視窗。它會直接使用個人預設：

```text
--duration 345600 --load 87
```

背景版本用 inter-process lock 阻止重複啟動第二份。

## 手動停止

可直接複製貼到 Windows CMD：

```cmd
taskkill /F /T /IM GPU-Stress-JUCE-Background.exe
```

或雙擊：

```text
STOP-JUCE-BACKUP.cmd
```

若你是用 CLI 執行，停止指令為：

```cmd
taskkill /F /T /IM GPU-Stress-JUCE-CLI.exe
```

## 確認是否正在執行

```cmd
tasklist /FI "IMAGENAME eq GPU-Stress-JUCE-Background.exe"
```

也可以雙擊：

```text
CHECK-JUCE-BACKUP.cmd
```

GPU 狀態仍可用：

```cmd
nvidia-smi
```

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

不碰 GPU 的完整流程 dry-run：

```cmd
GPU-Stress-JUCE-CLI.exe --dry-run --duration 5 --load 87
```

## 輸出位置

預設會在 EXE 旁建立：

```text
JUCE-Backup-Runs\
```

其中包含：

```text
gpu-stress-juce.pid
gpu-stress-juce-console.log
gpu-stress-juce-telemetry.csv
```

CSV 約每秒寫入一列，不會每個 200 ms duty window 都寫硬碟，因此適合放在 HDD 長跑。

## Quadro P2200 專用注意事項

- P2200 是 Pascal 架構，Release 明確編譯 `sm_61`。
- 預設 192 MiB VRAM 遠低於 5 GB，並保留至少 256 MiB 或總 VRAM 10% 給驅動與顯示用途。
- WaveMix 使用短 kernel，而不是 persistent kernel，目的是降低 Windows WDDM TDR 風險。
- `87%` 在這個版本代表每個 200 ms window 約要求 174 ms GPU active time；它不是保證 `nvidia-smi` 永遠顯示 87%，也不代表 87% TDP。
- 預設在 85 C 進入 thermal pause，降到 80 C 以下恢復。
- 第一次使用仍建議先跑 30 秒 25%，再跑 30 分鐘 87%，確認風扇、供電與穩定性後才啟動 96 小時。

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

Linux 仍需 NVIDIA driver；AppImage 不會內含或替換主機驅動。

## 測試範圍

CI 必須全部通過後才發布：

1. Host-only C++ unit tests
2. 96h／87% 預設與參數 parser
3. duty scheduler 與 overshoot
4. engine timed completion
5. stop request
6. backend initialization error
7. thermal pause 與 hysteresis 恢復
8. log／CSV／PID lifecycle
9. CUDA `sm_61` kernel 編譯
10. Windows CLI `--self-test`
11. Windows no-window background dry-run
12. Windows GUI smoke test
13. Linux CLI `--self-test`
14. Linux background dry-run under Xvfb
15. Linux GUI smoke test under Xvfb
16. AppImage extract-and-run smoke test

因 GitHub runner 沒有實體 Quadro P2200，真正 GPU kernel 執行、溫度與功耗曲線仍需在你的 P2200 主機做最後 hardware smoke test。
