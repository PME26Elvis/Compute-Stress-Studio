#pragma once

#include <string>
#include <vector>

namespace gpu_stress_backup {

struct AppConfig {
    int durationSeconds = GPU_STRESS_DEFAULT_DURATION_SECONDS;
    double loadPercent = GPU_STRESS_DEFAULT_LOAD_PERCENT;
    int memoryMiB = 192;
    int deviceIndex = 0;
    int dutyWindowMs = 200;
    int targetKernelMs = 8;
    bool background = false;
    bool dryRun = false;
    bool selfTest = false;
    bool showHelp = false;
    bool guiSmoke = false;

    [[nodiscard]] bool validate(std::string& error) const;
};

struct ParseResult {
    AppConfig config;
    bool ok = true;
    std::string error;
};

[[nodiscard]] ParseResult parseArguments(const std::vector<std::string>& arguments);
[[nodiscard]] std::string helpText();
[[nodiscard]] std::vector<std::string> splitCommandLine(const std::string& commandLine);

}  // namespace gpu_stress_backup
