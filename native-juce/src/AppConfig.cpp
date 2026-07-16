#include "GpuStressBackup/AppConfig.h"

#include <charconv>
#include <cctype>
#include <sstream>
#include <type_traits>

namespace gpu_stress_backup {
namespace {

template <typename T>
bool parseNumber(const std::string& text, T& value) {
    const char* begin = text.data();
    const char* end = text.data() + text.size();
    if constexpr (std::is_integral_v<T>) {
        const auto result = std::from_chars(begin, end, value);
        return result.ec == std::errc{} && result.ptr == end;
    } else {
        std::istringstream stream(text);
        stream >> value;
        return stream && stream.eof();
    }
}

bool takeValue(const std::vector<std::string>& arguments,
               std::size_t& index,
               const std::string& option,
               std::string& value,
               std::string& error) {
    const auto& argument = arguments[index];
    const auto prefix = option + "=";
    if (argument.rfind(prefix, 0) == 0) {
        value = argument.substr(prefix.size());
        if (value.empty()) {
            error = option + " requires a value";
            return false;
        }
        return true;
    }
    if (argument == option) {
        if (index + 1 >= arguments.size()) {
            error = option + " requires a value";
            return false;
        }
        value = arguments[++index];
        return true;
    }
    return false;
}

}  // namespace

bool AppConfig::validate(std::string& error) const {
    if (durationSeconds < 1 || durationSeconds > 14 * 24 * 60 * 60) {
        error = "duration must be between 1 second and 14 days";
        return false;
    }
    if (loadPercent < 0.0 || loadPercent > 100.0) {
        error = "load must be between 0 and 100 percent";
        return false;
    }
    if (memoryMiB < 32 || memoryMiB > 4096) {
        error = "memory-mib must be between 32 and 4096";
        return false;
    }
    if (deviceIndex < 0 || deviceIndex > 31) {
        error = "device must be between 0 and 31";
        return false;
    }
    if (dutyWindowMs < 50 || dutyWindowMs > 2000) {
        error = "window-ms must be between 50 and 2000";
        return false;
    }
    if (targetKernelMs < 1 || targetKernelMs > 50) {
        error = "kernel-ms must be between 1 and 50";
        return false;
    }
    return true;
}

ParseResult parseArguments(const std::vector<std::string>& arguments) {
    ParseResult result;
    for (std::size_t index = 0; index < arguments.size(); ++index) {
        const auto& argument = arguments[index];
        std::string value;

        if (argument == "-h" || argument == "--help") {
            result.config.showHelp = true;
        } else if (argument == "--background") {
            result.config.background = true;
        } else if (argument == "--dry-run") {
            result.config.dryRun = true;
        } else if (argument == "--self-test") {
            result.config.selfTest = true;
        } else if (argument == "--gui-smoke") {
            result.config.guiSmoke = true;
        } else if (takeValue(arguments, index, "--duration", value, result.error)) {
            if (!parseNumber(value, result.config.durationSeconds)) {
                result.ok = false;
                result.error = "invalid --duration value: " + value;
                return result;
            }
        } else if (takeValue(arguments, index, "--load", value, result.error)) {
            if (!parseNumber(value, result.config.loadPercent)) {
                result.ok = false;
                result.error = "invalid --load value: " + value;
                return result;
            }
        } else if (takeValue(arguments, index, "--memory-mib", value, result.error)) {
            if (!parseNumber(value, result.config.memoryMiB)) {
                result.ok = false;
                result.error = "invalid --memory-mib value: " + value;
                return result;
            }
        } else if (takeValue(arguments, index, "--device", value, result.error)) {
            if (!parseNumber(value, result.config.deviceIndex)) {
                result.ok = false;
                result.error = "invalid --device value: " + value;
                return result;
            }
        } else if (takeValue(arguments, index, "--window-ms", value, result.error)) {
            if (!parseNumber(value, result.config.dutyWindowMs)) {
                result.ok = false;
                result.error = "invalid --window-ms value: " + value;
                return result;
            }
        } else if (takeValue(arguments, index, "--kernel-ms", value, result.error)) {
            if (!parseNumber(value, result.config.targetKernelMs)) {
                result.ok = false;
                result.error = "invalid --kernel-ms value: " + value;
                return result;
            }
        } else {
            result.ok = false;
            if (result.error.empty()) {
                result.error = "unknown argument: " + argument;
            }
            return result;
        }
    }

    if (!result.config.showHelp && !result.config.validate(result.error)) {
        result.ok = false;
    }
    return result;
}

std::string helpText() {
    return R"HELP(GPU Stress JUCE Backup - silent custom CUDA WaveMix engine

Usage:
  GPU-Stress-JUCE.exe                         Open the JUCE GUI and tray app
  GPU-Stress-JUCE-Background.exe              Hidden 96h / 87% run
  GPU-Stress-JUCE-CLI.exe [options]            Silent console-mode run

Options:
  --duration SECONDS     Run duration; default 345600 (96 hours)
  --load PERCENT         Duty-window target; default 87
  --memory-mib MIB       WaveMix buffer budget; default 192
  --device INDEX         CUDA device index; default 0
  --window-ms MS         Duty scheduling window; default 200
  --kernel-ms MS         Calibrated short-kernel target; default 8
  --background           Run without creating a GUI window
  --dry-run              Use the synthetic backend; no GPU required
  --self-test            Run package-level non-GPU checks; exit code only
  --gui-smoke            Exercise GUI hide/restore and tray lifecycle, then exit
  -h, --help             Show this help

Normal stress runs are intentionally silent and do not launch monitoring tools,
write logs, create CSV files, or create PID files. The JUCE GUI can be hidden to
the notification area; double-click its tray icon to restore it, or right-click
the icon to stop the stress run or exit.

The WaveMix strategy is independent from the Python/cuBLAS implementation. It
uses short custom CUDA kernels mixing FP32 FMA, integer scrambling, shared-memory
permutations and global-memory traffic, then controls long-term load by measured
active time inside fixed duty windows.
)HELP";
}

std::vector<std::string> splitCommandLine(const std::string& commandLine) {
    std::vector<std::string> result;
    std::string current;
    bool quoted = false;
    char quoteCharacter = '\0';

    for (char character : commandLine) {
        if ((character == '"' || character == '\'') && (!quoted || character == quoteCharacter)) {
            if (!quoted) {
                quoted = true;
                quoteCharacter = character;
            } else {
                quoted = false;
                quoteCharacter = '\0';
            }
            continue;
        }
        if (std::isspace(static_cast<unsigned char>(character)) && !quoted) {
            if (!current.empty()) {
                result.push_back(current);
                current.clear();
            }
            continue;
        }
        current.push_back(character);
    }
    if (!current.empty()) {
        result.push_back(current);
    }
    return result;
}

}  // namespace gpu_stress_backup
