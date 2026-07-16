#include "GpuStressBackup/AppConfig.h"
#include "GpuStressBackup/DutyScheduler.h"
#include "GpuStressBackup/StressBackend.h"
#include "GpuStressBackup/StressEngine.h"

#include <atomic>
#include <chrono>
#include <cmath>
#include <csignal>
#include <iostream>
#include <memory>
#include <thread>
#include <vector>

namespace {

std::atomic<gpu_stress_backup::StressEngine*> activeEngine{nullptr};

void handleSignal(int) {
    if (auto* engine = activeEngine.load(); engine != nullptr) {
        engine->requestStop();
    }
}

bool runSelfTest() {
    using namespace gpu_stress_backup;
    const auto defaults = parseArguments({});
    if (!defaults.ok || defaults.config.durationSeconds != 345600 ||
        std::abs(defaults.config.loadPercent - 87.0) > 0.001) {
        return false;
    }

    DutyScheduler scheduler(87.0, 200);
    if (std::abs(scheduler.activeBudgetMilliseconds() - 174.0) > 0.001 ||
        std::abs(scheduler.idleBudgetMilliseconds(174.0) - 26.0) > 0.001) {
        return false;
    }

    AppConfig config;
    config.durationSeconds = 1;
    config.loadPercent = 50.0;
    config.dutyWindowMs = 50;
    config.dryRun = true;

    StressEngine engine(makeSyntheticStressBackend());
    std::string error;
    if (!engine.start(config, error)) {
        return false;
    }
    engine.wait();
    const auto snapshot = engine.snapshot();
    return snapshot.state == EngineState::Completed && snapshot.completedWindows > 0;
}

std::unique_ptr<gpu_stress_backup::IStressBackend> makeBackend(bool dryRun) {
    if (dryRun) {
        return gpu_stress_backup::makeSyntheticStressBackend();
    }
#if GPU_STRESS_HAS_CUDA
    return gpu_stress_backup::makeCudaWaveMixBackend();
#else
    return {};
#endif
}

}  // namespace

int main(int argc, char** argv) {
    using namespace gpu_stress_backup;

    std::vector<std::string> arguments;
    for (int index = 1; index < argc; ++index) {
        arguments.emplace_back(argv[index]);
    }

    auto parsed = parseArguments(arguments);
    if (!parsed.ok) {
        return 2;
    }
    if (parsed.config.showHelp) {
        std::cout << helpText();
        return 0;
    }
    if (parsed.config.selfTest) {
        return runSelfTest() ? 0 : 3;
    }

    auto backend = makeBackend(parsed.config.dryRun);
    if (backend == nullptr) {
        return 2;
    }

    StressEngine engine(std::move(backend));
    std::signal(SIGINT, handleSignal);
    std::signal(SIGTERM, handleSignal);
    activeEngine.store(&engine);

    std::string error;
    if (!engine.start(parsed.config, error)) {
        activeEngine.store(nullptr);
        return 2;
    }

    while (engine.isRunning()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }
    engine.wait();
    activeEngine.store(nullptr);

    return engine.snapshot().state == EngineState::Error ? 2 : 0;
}
