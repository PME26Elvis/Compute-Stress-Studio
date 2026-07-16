#pragma once

#include "GpuStressBackup/AppConfig.h"

#include <memory>
#include <string>

namespace gpu_stress_backup {

struct BackendInfo {
    std::string strategyName;
    std::string deviceName;
    std::size_t allocatedBytes = 0;
    int calibratedIterations = 0;
    double calibratedKernelMs = 0.0;
};

class IStressBackend {
public:
    virtual ~IStressBackend() = default;
    virtual bool initialize(const AppConfig& config, std::string& error) = 0;
    virtual double runActiveFor(double requestedMilliseconds, std::string& error) = 0;
    virtual void shutdown() noexcept = 0;
    [[nodiscard]] virtual BackendInfo info() const = 0;
};

[[nodiscard]] std::unique_ptr<IStressBackend> makeSyntheticStressBackend();
[[nodiscard]] std::unique_ptr<IStressBackend> makeCudaWaveMixBackend();

}  // namespace gpu_stress_backup
