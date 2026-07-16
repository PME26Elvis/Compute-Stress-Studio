#include "TestHarness.h"

#include "GpuStressBackup/StressBackend.h"
#include "GpuStressBackup/StressEngine.h"

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

class RuntimeFailingBackend final : public IStressBackend {
public:
    bool initialize(const AppConfig&, std::string&) override { return true; }
    double runActiveFor(double, std::string& error) override {
        error = "intentional runtime failure";
        return 0.0;
    }
    void shutdown() noexcept override { shutdownCalled = true; }
    BackendInfo info() const override { return {}; }

    bool shutdownCalled = false;
};

}  // namespace

GPU_TEST_CASE("synthetic engine completes a timed run") {
    AppConfig config;
    config.durationSeconds = 1;
    config.loadPercent = 50.0;
    config.dutyWindowMs = 50;
    config.dryRun = true;

    StressEngine engine(makeSyntheticStressBackend());
    std::string error;
    GPU_REQUIRE(engine.start(config, error));
    engine.wait();

    const auto snapshot = engine.snapshot();
    GPU_REQUIRE(snapshot.state == EngineState::Completed);
    GPU_REQUIRE(snapshot.completedWindows >= 10);
    GPU_REQUIRE(snapshot.elapsedSeconds >= 0.9);
    GPU_REQUIRE(snapshot.remainingSeconds == 0.0);
}

GPU_TEST_CASE("stop request ends a long synthetic run early") {
    AppConfig config;
    config.durationSeconds = 10;
    config.loadPercent = 50.0;
    config.dutyWindowMs = 50;
    config.dryRun = true;

    StressEngine engine(makeSyntheticStressBackend());
    std::string error;
    GPU_REQUIRE(engine.start(config, error));
    std::this_thread::sleep_for(std::chrono::milliseconds(180));
    engine.requestStop();
    engine.wait();

    const auto snapshot = engine.snapshot();
    GPU_REQUIRE(snapshot.state == EngineState::Completed);
    GPU_REQUIRE(snapshot.elapsedSeconds < 3.0);
    GPU_REQUIRE(snapshot.remainingSeconds > 0.0);
}

GPU_TEST_CASE("backend initialization failure becomes engine error") {
    AppConfig config;
    config.durationSeconds = 1;
    StressEngine engine(std::make_unique<FailingBackend>());
    std::string error;
    GPU_REQUIRE(engine.start(config, error));
    engine.wait();

    const auto snapshot = engine.snapshot();
    GPU_REQUIRE(snapshot.state == EngineState::Error);
    GPU_REQUIRE(snapshot.error.find("intentional") != std::string::npos);
}

GPU_TEST_CASE("backend runtime failure becomes engine error") {
    AppConfig config;
    config.durationSeconds = 1;
    config.dutyWindowMs = 50;
    auto backend = std::make_unique<RuntimeFailingBackend>();
    StressEngine engine(std::move(backend));
    std::string error;
    GPU_REQUIRE(engine.start(config, error));
    engine.wait();

    const auto snapshot = engine.snapshot();
    GPU_REQUIRE(snapshot.state == EngineState::Error);
    GPU_REQUIRE(snapshot.error.find("runtime") != std::string::npos);
}

GPU_TEST_CASE("engine rejects a second concurrent start") {
    AppConfig config;
    config.durationSeconds = 2;
    config.loadPercent = 10.0;
    config.dutyWindowMs = 50;
    config.dryRun = true;

    StressEngine engine(makeSyntheticStressBackend());
    std::string firstError;
    GPU_REQUIRE(engine.start(config, firstError));
    std::string secondError;
    GPU_REQUIRE(!engine.start(config, secondError));
    GPU_REQUIRE(secondError.find("already") != std::string::npos);
    engine.requestStop();
    engine.wait();
}
