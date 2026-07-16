#include "GpuStressBackup/StressBackend.h"

#include <algorithm>
#include <chrono>
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

}  // namespace

std::unique_ptr<IStressBackend> makeSyntheticStressBackend() {
    return std::make_unique<SyntheticStressBackend>();
}

#if !GPU_STRESS_HAS_CUDA
std::unique_ptr<IStressBackend> makeCudaWaveMixBackend() {
    return {};
}
#endif

}  // namespace gpu_stress_backup
