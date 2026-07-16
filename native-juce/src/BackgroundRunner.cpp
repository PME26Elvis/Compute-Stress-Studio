#include "GpuStressBackup/BackgroundRunner.h"

#include "GpuStressBackup/RunLogger.h"
#include "GpuStressBackup/StressBackend.h"
#include "GpuStressBackup/Telemetry.h"

#include <filesystem>
#include <fstream>

namespace gpu_stress_backup {

BackgroundRunner::BackgroundRunner(AppConfig config) : config_(std::move(config)) {}

BackgroundRunner::~BackgroundRunner() {
    stop();
}

bool BackgroundRunner::start(std::string& error) {
    if (!processLock_.enter(0)) {
        error = "another JUCE backup background run is already active";
        writeStartupFailure(error);
        return false;
    }

    if (config_.outputDirectory.empty()) {
        config_.outputDirectory = defaultOutputDirectory();
    }
    config_.background = true;

    auto backend = createBackend();
    if (backend == nullptr) {
        error = "this build does not include the CUDA WaveMix backend; use --dry-run";
        writeStartupFailure(error);
        processLock_.exit();
        return false;
    }

    auto telemetry = config_.telemetryEnabled
                         ? (config_.dryRun ? makeSyntheticTelemetry() : makeNvidiaSmiTelemetry())
                         : std::unique_ptr<ITelemetryProvider>{};
    engine_ = std::make_unique<StressEngine>(
        std::move(backend), std::move(telemetry), std::make_unique<RunLogger>());

    if (!engine_->start(config_, error)) {
        writeStartupFailure(error);
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

std::filesystem::path BackgroundRunner::defaultOutputDirectory() const {
    const auto executable = juce::File::getSpecialLocation(juce::File::currentExecutableFile);
    return std::filesystem::path(executable.getParentDirectory().getFullPathName().toStdString()) /
           "JUCE-Backup-Runs";
}

void BackgroundRunner::writeStartupFailure(const std::string& message) const {
    auto directory = config_.outputDirectory.empty() ? defaultOutputDirectory()
                                                     : config_.outputDirectory;
    std::error_code ignored;
    std::filesystem::create_directories(directory, ignored);
    std::ofstream stream(directory / "gpu-stress-juce-startup-error.log",
                         std::ios::out | std::ios::app);
    if (stream) {
        stream << message << '\n';
    }
}

}  // namespace gpu_stress_backup
