#include "GpuStressBackup/BackgroundRunner.h"

#include "GpuStressBackup/StressBackend.h"

namespace gpu_stress_backup {

BackgroundRunner::BackgroundRunner(AppConfig config) : config_(std::move(config)) {}

BackgroundRunner::~BackgroundRunner() {
    stop();
}

bool BackgroundRunner::start(std::string& error) {
    if (!processLock_.enter(0)) {
        error = "another JUCE backup background run is already active";
        return false;
    }

    config_.background = true;
    auto backend = createBackend();
    if (backend == nullptr) {
        error = "this build does not include the CUDA WaveMix backend; use --dry-run";
        processLock_.exit();
        return false;
    }

    engine_ = std::make_unique<StressEngine>(std::move(backend));
    if (!engine_->start(config_, error)) {
        engine_.reset();
        processLock_.exit();
        return false;
    }

    startTimerHz(5);
    return true;
}

void BackgroundRunner::stop() {
    stopTimer();
    if (engine_ != nullptr) {
        engine_->requestStop();
        engine_->wait();
        engine_.reset();
    }
    processLock_.exit();
}

void BackgroundRunner::timerCallback() {
    if (engine_ == nullptr || !engine_->isRunning()) {
        stopTimer();
        juce::JUCEApplicationBase::quit();
    }
}

std::unique_ptr<IStressBackend> BackgroundRunner::createBackend() const {
    if (config_.dryRun) {
        return makeSyntheticStressBackend();
    }
#if GPU_STRESS_HAS_CUDA
    return makeCudaWaveMixBackend();
#else
    return {};
#endif
}

}  // namespace gpu_stress_backup
