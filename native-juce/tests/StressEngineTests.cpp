#include "TestHarness.h"

#include "GpuStressBackup/StressBackend.h"
#include "GpuStressBackup/StressEngine.h"
#include "GpuStressBackup/Telemetry.h"

#include <atomic>
#include <chrono>
#include <memory>
#include <string>
#include <thread>

using namespace gpu_stress_backup;

namespace {

class FailingBackend final : public IStressBackend {
public:
    bool initialize(const AppConfig&, std::string& error) override {
        error = "intentional initialization failure";
        return false;
    }
    double runActiveFor(double, std::string&) override { return 0.0; }
    void shutdown() noexcept override {}
    BackendInfo info() const override { return {}; }
};

class HotThenCoolTelemetry final : public ITelemetryProvider {
public:
    TelemetrySample sample(int) override {
        TelemetrySample result;
        result.available = true;
        result.deviceName = "Thermal test GPU";
        result.temperatureC = calls_++ == 0 ? 90.0 : 70.0;
        result.utilizationPercent = 87.0;
        return result;
    }

private:
    int calls_ = 0;
};

}  // namespace

GPU_TEST_CASE("synthetic engine completes a timed run") {
    AppConfig config;
    config.durationSeconds = 1;
    config.loadPercent = 50.0;
    config.dutyWindowMs = 50;
    config.dryRun = true;

    StressEngine engine(makeSyntheticStressBackend(), makeSyntheticTelemetry());
    std::string error;
    GPU_REQUIRE(engine.start(config, error));
    engine.wait();

    const auto snapshot = engine.snapshot();
    GPU_REQUIRE(snapshot.state == EngineState::Completed);
    GPU_REQUIRE(snapshot.completedWindows >= 10);
    GPU_REQUIRE(snapshot.elapsedSeconds >= 0.9);
}

GPU_TEST_CASE("stop request ends a long synthetic run early") {
    AppConfig config;
    config.durationSeconds = 10;
    config.loadPercent = 50.0;
    config.dutyWindowMs = 50;
    config.dryRun = true;

    StressEngine engine(makeSyntheticStressBackend(), makeSyntheticTelemetry());
    std::string error;
    GPU_REQUIRE(engine.start(config, error));
    std::this_thread::sleep_for(std::chrono::milliseconds(180));
    engine.requestStop();
    engine.wait();

    const auto snapshot = engine.snapshot();
    GPU_REQUIRE(snapshot.state == EngineState::Completed);
    GPU_REQUIRE(snapshot.elapsedSeconds < 3.0);
}

GPU_TEST_CASE("backend initialization failure becomes engine error") {
    AppConfig config;
    config.durationSeconds = 1;
    StressEngine engine(std::make_unique<FailingBackend>(), makeSyntheticTelemetry());
    std::string error;
    GPU_REQUIRE(engine.start(config, error));
    engine.wait();

    const auto snapshot = engine.snapshot();
    GPU_REQUIRE(snapshot.state == EngineState::Error);
    GPU_REQUIRE(snapshot.error.find("intentional") != std::string::npos);
}

GPU_TEST_CASE("thermal guard pauses then resumes after hysteresis") {
    AppConfig config;
    config.durationSeconds = 2;
    config.loadPercent = 50.0;
    config.dutyWindowMs = 50;
    config.temperatureLimitC = 80;
    config.dryRun = true;

    StressEngine engine(makeSyntheticStressBackend(), std::make_unique<HotThenCoolTelemetry>());
    std::string error;
    GPU_REQUIRE(engine.start(config, error));

    bool sawThermalPause = false;
    while (engine.isRunning()) {
        if (engine.snapshot().state == EngineState::ThermalPause) {
            sawThermalPause = true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    engine.wait();

    GPU_REQUIRE(sawThermalPause);
    GPU_REQUIRE(engine.snapshot().state == EngineState::Completed);
}
