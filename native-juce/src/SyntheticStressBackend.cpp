#include "GpuStressBackup/StressBackend.h"
#include "GpuStressBackup/Telemetry.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <thread>

namespace gpu_stress_backup {
namespace {

class SyntheticStressBackend final : public IStressBackend {
public:
    bool initialize(const AppConfig& config, std::string&) override {
        initialized_ = true;
        info_.strategyName = "Synthetic WaveMix dry-run";
        info_.deviceName = "Synthetic NVIDIA GPU";
        info_.allocatedBytes = static_cast<std::size_t>(config.memoryMiB) * 1024U * 1024U;
        info_.calibratedIterations = 1024;
        info_.calibratedKernelMs = static_cast<double>(config.targetKernelMs);
        return true;
    }

    double runActiveFor(double requestedMilliseconds, std::string& error) override {
        if (!initialized_) {
            error = "synthetic backend is not initialized";
            return 0.0;
        }
        const auto bounded = std::max(0.0, requestedMilliseconds);
        const auto started = std::chrono::steady_clock::now();
        std::this_thread::sleep_for(std::chrono::duration<double, std::milli>(bounded));
        const auto elapsed = std::chrono::steady_clock::now() - started;
        return std::chrono::duration<double, std::milli>(elapsed).count();
    }

    void shutdown() noexcept override {
        initialized_ = false;
    }

    BackendInfo info() const override {
        return info_;
    }

private:
    bool initialized_ = false;
    BackendInfo info_;
};

class SyntheticTelemetry final : public ITelemetryProvider {
public:
    TelemetrySample sample(int) override {
        phase_ += 0.17;
        TelemetrySample sample;
        sample.available = true;
        sample.deviceName = "Synthetic NVIDIA GPU";
        sample.utilizationPercent = 87.0 + std::sin(phase_) * 2.0;
        sample.temperatureC = 66.0 + std::sin(phase_ * 0.3) * 3.0;
        sample.powerWatts = 61.0 + std::sin(phase_ * 0.7) * 4.0;
        sample.memoryUsedMiB = 192.0;
        sample.memoryTotalMiB = 5120.0;
        return sample;
    }

private:
    double phase_ = 0.0;
};

}  // namespace

std::unique_ptr<IStressBackend> makeSyntheticStressBackend() {
    return std::make_unique<SyntheticStressBackend>();
}

std::unique_ptr<ITelemetryProvider> makeSyntheticTelemetry() {
    return std::make_unique<SyntheticTelemetry>();
}

#if !GPU_STRESS_HAS_CUDA
std::unique_ptr<IStressBackend> makeCudaWaveMixBackend() {
    return {};
}
#endif

}  // namespace gpu_stress_backup
