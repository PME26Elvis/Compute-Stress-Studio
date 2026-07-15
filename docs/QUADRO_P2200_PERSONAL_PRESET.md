# Quadro P2200 個人預設版操作指南

這份文件專門對應以下使用環境與本次修改：

- Windows 10 Pro
- NVIDIA Quadro P2200 5 GB
- NVIDIA 驅動 561.17
- CUDA 12.6 相容環境
- GPU 壓力測試預設執行 **96 小時**
- 目標 GPU utilization 預設為 **87%**

> 96 小時等於 `96 × 60 × 60 = 345600` 秒。

## 下載哪個檔案

從 GitHub Release 下載：

```text
GPU-Stress-Portable-Windows-x64.zip
```

請完整解壓整個 ZIP。不要只單獨搬動其中一個 EXE，因為 CUDA、CuPy 與 Python runtime 位於旁邊的 `_internal` 目錄。

整個解壓後的資料夾可以放在 HDD。穩定運行後，主要負載發生在 GPU、VRAM 與 RAM，不會持續大量讀寫硬碟。

## 最簡單的啟動方式：直接雙擊

直接雙擊：

```text
GPU-Stress-P2200-Background.exe
```

它會：

1. 不顯示 CMD 或 PowerShell 視窗。
2. 在背景啟動 `GPU-Stress-P2200-Worker.exe`。
3. 預設執行 345600 秒，也就是 96 小時。
4. 預設目標 load 為 87%。
5. 自動輸出 PID、console log 與 CSV。
6. 如果偵測到同一個背景 worker 已在執行，不會重複啟動第二份。

也可以雙擊：

```text
START-P2200-96H-87.cmd
```

這個 CMD 只是呼叫同一個無視窗 launcher。

## 從 Windows CMD 啟動

切換到程式資料夾後執行：

```cmd
GPU-Stress-P2200-Background.exe
```

此命令會立即返回 CMD，真正的 GPU 壓力程序會留在背景執行。

## 手動停止：可直接複製貼上的 CMD

```cmd
taskkill /F /T /IM GPU-Stress-P2200-Worker.exe
```

這是最直接、最可靠的停止命令。`/T` 會一起終止其子程序，`/F` 會強制結束。

停止後也可以清掉舊 PID 檔：

```cmd
del /Q "P2200-Runs\gpu-stress-p2200.pid"
```

或者直接雙擊：

```text
STOP-P2200-GPU-STRESS.cmd
```

## 確認是否正在執行

```cmd
tasklist /FI "IMAGENAME eq GPU-Stress-P2200-Worker.exe"
```

看到 `GPU-Stress-P2200-Worker.exe` 代表背景壓力程序仍在執行。

也可以使用：

```cmd
nvidia-smi
```

查看 GPU utilization、溫度、功耗與目前程序。

## 輸出檔案位置

背景 launcher 會在程式資料夾內建立：

```text
P2200-Runs\
```

其中包含：

```text
gpu-stress-p2200.pid
gpu-stress-p2200-console.log
gpu-stress-p2200.csv
```

- `gpu-stress-p2200.pid`：目前背景 worker 的 PID。
- `gpu-stress-p2200-console.log`：啟動資訊、即時狀態與錯誤。
- `gpu-stress-p2200.csv`：完整 telemetry，包含 utilization、溫度、功耗、時脈與 VRAM。

因為 `P2200-Runs` 位於解壓資料夾內，所以把整包放在 HDD 時，log 與 CSV 也會留在 HDD。

## 直接執行 worker

需要看即時文字輸出或做診斷時，使用：

```cmd
GPU-Stress-P2200-Worker.exe --diagnose
```

短時間低負載測試：

```cmd
GPU-Stress-P2200-Worker.exe --duration 30 --load 25
```

直接不帶參數執行 worker：

```cmd
GPU-Stress-P2200-Worker.exe
```

同樣會使用新的個人預設：

```text
--duration 345600 --load 87
```

## 覆蓋個人預設

例如改成 2 小時、75%：

```cmd
GPU-Stress-P2200-Worker.exe --duration 7200 --load 75
```

背景執行自訂參數：

```cmd
GPU-Stress-P2200-Background.exe --duration 7200 --load 75
```

只要明確提供 `--duration` 或 `--load`，程式就不會用 96 小時／87% 覆蓋你的設定。

## Quadro P2200 注意事項

- Quadro P2200 沒有 Tensor Cores，本工具的預設 FP32 CuPy/cuBLAS 路徑適合這張卡。
- 預設 VRAM budget 只有 256 MiB，遠低於 5 GB，主要目標是提高運算負載，不是刻意塞滿顯存。
- 87% 是 GPU utilization 目標，不等同於 87% TDP 或固定瓦數。
- 預設溫度保護仍有效；到達溫度上限時會暫停，降溫後再恢復。
- 96 小時屬於長時間測試。第一次使用建議先跑 30 秒 25%，再跑 10 到 30 分鐘 87%，確認散熱、風扇與穩定性後再正式啟動 96 小時。

建議的前置測試：

```cmd
GPU-Stress-P2200-Worker.exe --diagnose
GPU-Stress-P2200-Worker.exe --duration 30 --load 25
GPU-Stress-P2200-Worker.exe --duration 1800 --load 87
```

## AppImage 與 Linux

Linux Release 另外提供：

```text
GPU-Stress-Portable-x86_64.AppImage
```

加上執行權限後可直接執行：

```bash
chmod +x GPU-Stress-Portable-x86_64.AppImage
./GPU-Stress-Portable-x86_64.AppImage
```

AppImage 不帶參數時同樣使用 345600 秒與 87%。Windows 的無視窗背景 launcher 與 `taskkill` 操作只存在於 Windows ZIP。
