#pragma once

#include "GpuStressBackup/AppConfig.h"
#include "GpuStressBackup/StressEngine.h"

#include <filesystem>
#include <fstream>
#include <mutex>
#include <string>

namespace gpu_stress_backup {

class RunLogger {
public:
    RunLogger() = default;
    ~RunLogger();

    RunLogger(const RunLogger&) = delete;
    RunLogger& operator=(const RunLogger&) = delete;

    bool open(const std::filesystem::path& directory, const AppConfig& config, std::string& error);
    void writeMessage(const std::string& message);
    void writeSnapshot(const EngineSnapshot& snapshot);
    void close() noexcept;

    [[nodiscard]] std::filesystem::path directory() const;
    [[nodiscard]] std::filesystem::path logPath() const;
    [[nodiscard]] std::filesystem::path csvPath() const;
    [[nodiscard]] std::filesystem::path pidPath() const;

private:
    static std::string timestamp();
    static unsigned long currentProcessId();
    static std::string csvEscape(const std::string& value);

    mutable std::mutex mutex_;
    std::filesystem::path directory_;
    std::filesystem::path logPath_;
    std::filesystem::path csvPath_;
    std::filesystem::path pidPath_;
    std::ofstream logStream_;
    std::ofstream csvStream_;
    bool opened_ = false;
};

}  // namespace gpu_stress_backup
