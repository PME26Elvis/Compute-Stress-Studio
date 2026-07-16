#include "GpuStressBackup/StressEngine.h"

#include "GpuStressBackup/DutyScheduler.h"
#include "GpuStressBackup/RunLogger.h"

#include <algorithm>
#include <chrono>
#include <thread>

namespace gpu_stress_backup {

StressEngine::StressEngine(std::unique_ptr<IStressBackend> backend,
                           std::unique_ptr<ITelemetryProvider> telemetry,
                           std::unique_ptr<RunLogger> logger)
    : backend_(std::move(backend)), telemetry_(std::move(telemetry)), logger_(std::move(logger)) {}

StressEngine::~StressEngine() {
    requestStop();
    wait();
}

bool StressEngine::start(const AppConfig& config, std::string& error) {
    if (running_.load()) {
        error = "stress engine is already running";
        return false;
    }
    if (backend_ == nullptr) {
        error = "no stress backend is available";
        return false;
    }
    if (!config.validate(error)) {
        return false;
    }
    if (worker_.joinable()) {
        worker_.join();
    }

    stopRequested_.store(false);
    running_.store(true);
    worker_ = std::thread([this, config] { run(config); });
    return true;
}

void StressEngine::requestStop() noexcept {
    stopRequested_.store(true);
}

void StressEngine::wait() {
    if (worker_.joinable()) {
        worker_.join();
    }
}

bool StressEngine::isRunning() const noexcept {
    return running_.load();
}

EngineSnapshot StressEngine::snapshot() const {
    std::scoped_lock lock(snapshotMutex_);
    return snapshot_;
}

void StressEngine::run(AppConfig config) {
    EngineSnapshot current;
    current.state = EngineState::Initializing;
    current.stateText = stateToText(current.state);
    current.targetLoadPercent = config.loadPercent;
    current.remainingSeconds = static_cast<double>(config.durationSeconds);
    publish(current);

    if (logger_ != nullptr && !config.outputDirectory.empty()) {
        std::string loggerError;
        if (!logger_->open(config.outputDirectory, config, loggerError)) {
            current.state = EngineState::Error;
            current.stateText = stateToText(current.state);
            current.error = loggerError;
            publish(current);
            running_.store(false);
            return;
        }
    }

    std::string backendError;
    if (!backend_->initialize(config, backendError)) {
        current.state = EngineState::Error;
        current.stateText = stateToText(current.state);
        current.error = backendError;
        publish(current);
        if (logger_ != nullptr) {
            logger_->writeMessage("backend initialization failed: " + backendError);
            logger_->close();
        }
        running_.store(false);
        return;
    }

    current.backend = backend_->info();
    current.state = EngineState::Running;
    current.stateText = stateToText(current.state);
    publish(current);
    if (logger_ != nullptr) {
        logger_->writeMessage("backend ready: " + current.backend.strategyName +
                              " on " + current.backend.deviceName);
    }

    DutyScheduler scheduler(config.loadPercent, config.dutyWindowMs);
    const auto started = std::chrono::steady_clock::now();
    auto nextTelemetry = started;
    auto nextLog = started;
    bool thermalPaused = false;

    while (!stopRequested_.load()) {
        const auto windowStarted = std::chrono::steady_clock::now();
        current.elapsedSeconds =
            std::chrono::duration<double>(windowStarted - started).count();
        current.remainingSeconds =
            std::max(0.0, static_cast<double>(config.durationSeconds) - current.elapsedSeconds);
        if (current.elapsedSeconds >= static_cast<double>(config.durationSeconds)) {
            break;
        }

        if (config.telemetryEnabled && telemetry_ != nullptr && windowStarted >= nextTelemetry) {
            current.telemetry = telemetry_->sample(config.deviceIndex);
            nextTelemetry = windowStarted + std::chrono::seconds(1);

            if (config.temperatureLimitC > 0 && current.telemetry.available) {
                if (!thermalPaused && current.telemetry.temperatureC >= config.temperatureLimitC) {
                    thermalPaused = true;
                    current.state = EngineState::ThermalPause;
                    current.stateText = stateToText(current.state);
                    if (logger_ != nullptr) {
                        logger_->writeMessage("thermal pause at " +
                                              std::to_string(current.telemetry.temperatureC) + " C");
                    }
                } else if (thermalPaused &&
                           current.telemetry.temperatureC <= config.temperatureLimitC - 5) {
                    thermalPaused = false;
                    current.state = EngineState::Running;
                    current.stateText = stateToText(current.state);
                    if (logger_ != nullptr) {
                        logger_->writeMessage("thermal pause cleared");
                    }
                }
            }
        }

        if (thermalPaused) {
            current.lastActiveMilliseconds = 0.0;
            current.lastIdleMilliseconds = static_cast<double>(config.dutyWindowMs);
            std::this_thread::sleep_for(std::chrono::milliseconds(config.dutyWindowMs));
        } else {
            std::string runError;
            const auto requested = scheduler.activeBudgetMilliseconds();
            const auto active = backend_->runActiveFor(requested, runError);
            if (!runError.empty()) {
                current.state = EngineState::Error;
                current.stateText = stateToText(current.state);
                current.error = runError;
                publish(current);
                if (logger_ != nullptr) {
                    logger_->writeMessage("backend failed: " + runError);
                }
                break;
            }

            const auto idle = scheduler.idleBudgetMilliseconds(active);
            current.lastActiveMilliseconds = active;
            current.lastIdleMilliseconds = idle;
            if (idle > 0.0) {
                std::this_thread::sleep_for(std::chrono::duration<double, std::milli>(idle));
            }
        }

        ++current.completedWindows;
        const auto afterWindow = std::chrono::steady_clock::now();
        current.elapsedSeconds = std::chrono::duration<double>(afterWindow - started).count();
        current.remainingSeconds =
            std::max(0.0, static_cast<double>(config.durationSeconds) - current.elapsedSeconds);
        current.backend = backend_->info();
        publish(current);

        if (logger_ != nullptr && afterWindow >= nextLog) {
            logger_->writeSnapshot(current);
            nextLog = afterWindow + std::chrono::seconds(1);
        }
    }

    if (current.state != EngineState::Error) {
        current.state = stopRequested_.load() ? EngineState::Stopping : EngineState::Completed;
        current.stateText = stateToText(current.state);
        publish(current);
    }

    backend_->shutdown();

    if (current.state != EngineState::Error) {
        current.state = EngineState::Completed;
        current.stateText = stateToText(current.state);
        current.remainingSeconds = 0.0;
        publish(current);
        if (logger_ != nullptr) {
            logger_->writeSnapshot(current);
            logger_->writeMessage(stopRequested_.load() ? "run stopped by request" : "run completed");
        }
    }

    if (logger_ != nullptr) {
        logger_->close();
    }
    running_.store(false);
}

void StressEngine::publish(EngineSnapshot snapshot) {
    std::scoped_lock lock(snapshotMutex_);
    snapshot_ = std::move(snapshot);
}

std::string StressEngine::stateToText(EngineState state) {
    switch (state) {
        case EngineState::Idle: return "Idle";
        case EngineState::Initializing: return "Initializing";
        case EngineState::Running: return "Running";
        case EngineState::ThermalPause: return "Thermal pause";
        case EngineState::Stopping: return "Stopping";
        case EngineState::Completed: return "Completed";
        case EngineState::Error: return "Error";
    }
    return "Unknown";
}

}  // namespace gpu_stress_backup
