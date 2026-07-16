#pragma once

#include "GpuStressBackup/AppConfig.h"
#include "GpuStressBackup/StressBackend.h"
#include "GpuStressBackup/Telemetry.h"

#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace gpu_stress_backup {

class RunLogger;

enum class EngineState {
    Idle,
    Initializing,
    Running,
    ThermalPause,
    Stopping,
    Completed,
    Error
};

struct EngineSnapshot {
    EngineState state = EngineState::Idle;
    std::string stateText = "Idle";
    std::string error;
    BackendInfo backend;
    TelemetrySample telemetry;
    double targetLoadPercent = 0.0;
    double elapsedSeconds = 0.0;
    double remainingSeconds = 0.0;
    double lastActiveMilliseconds = 0.0;
    double lastIdleMilliseconds = 0.0;
    std::uint64_t completedWindows = 0;
};

class StressEngine {
public:
    StressEngine(std::unique_ptr<IStressBackend> backend,
                 std::unique_ptr<ITelemetryProvider> telemetry,
                 std::unique_ptr<RunLogger> logger = {});
    ~StressEngine();

    StressEngine(const StressEngine&) = delete;
    StressEngine& operator=(const StressEngine&) = delete;

    bool start(const AppConfig& config, std::string& error);
    void requestStop() noexcept;
    void wait();

    [[nodiscard]] bool isRunning() const noexcept;
    [[nodiscard]] EngineSnapshot snapshot() const;

private:
    void run(AppConfig config);
    void publish(EngineSnapshot snapshot);
    static std::string stateToText(EngineState state);

    std::unique_ptr<IStressBackend> backend_;
    std::unique_ptr<ITelemetryProvider> telemetry_;
    std::unique_ptr<RunLogger> logger_;
    std::thread worker_;
    std::atomic<bool> stopRequested_{false};
    std::atomic<bool> running_{false};
    mutable std::mutex snapshotMutex_;
    EngineSnapshot snapshot_;
};

}  // namespace gpu_stress_backup
