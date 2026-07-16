#pragma once

#include "GpuStressBackup/AppConfig.h"
#include "GpuStressBackup/StressEngine.h"

#include <juce_core/juce_core.h>

#include <memory>

namespace gpu_stress_backup {

class BackgroundRunner final : private juce::Timer {
public:
    explicit BackgroundRunner(AppConfig config);
    ~BackgroundRunner() override;

    bool start(std::string& error);
    void stop();

private:
    void timerCallback() override;
    [[nodiscard]] std::unique_ptr<IStressBackend> createBackend() const;
    [[nodiscard]] std::filesystem::path defaultOutputDirectory() const;
    void writeStartupFailure(const std::string& message) const;

    AppConfig config_;
    juce::InterProcessLock processLock_{"GPUStressJUCEBackupBackground"};
    std::unique_ptr<StressEngine> engine_;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BackgroundRunner)
};

}  // namespace gpu_stress_backup
