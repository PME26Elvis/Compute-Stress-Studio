#include "GpuStressBackup/AppConfig.h"
#include "GpuStressBackup/DutyScheduler.h"
#include "GpuStressBackup/RunLogger.h"
#include "GpuStressBackup/StressBackend.h"
#include "GpuStressBackup/StressEngine.h"
#include "GpuStressBackup/Telemetry.h"

#include <atomic>
#include <chrono>
#include <cmath>
#include <csignal>
#include <filesystem>
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
        std::cerr << "self-test: personal defaults failed\n";
        return false;
    }

    DutyScheduler scheduler(87.0, 200);
    if (std::abs(scheduler.activeBudgetMilliseconds() - 174.0) > 0.001 ||
        std::abs(scheduler.idleBudgetMilliseconds(174.0) - 26.0) > 0.001) {
        std::cerr << "self-test: duty scheduler failed\n";
        return false;
    }

    AppConfig config;
    config.durationSeconds = 1;
    config.loadPercent = 50.0;
    config.dutyWindowMs = 50;
    config.dryRun = true;
    config.telemetryEnabled = true;

    StressEngine engine(makeSyntheticStressBackend(), makeSyntheticTelemetry());
    std::string error;
    if (!engine.start(config, error)) {
        std::cerr << "self-test: synthetic engine failed to start: " << error << '\n';
        return false;
    }
    engine.wait();
    const auto snapshot = engine.snapshot();
    if (snapshot.state != EngineState::Completed || snapshot.completedWindows == 0) {
        std::cerr << "self-test: synthetic engine did not complete\n";
        return false;
    }

    std::cout << "self-test: defaults, scheduler, telemetry, and engine passed\n";
    return true;
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
        std::cerr << "error: " << parsed.error << "\n\n" << helpText();
        return 2;
    }
    if (parsed.config.showHelp) {
        std::cout << helpText();
        return 0;
    }
    if (parsed.config.selfTest) {
        return runSelfTest() ? 0 : 3;
    }

    if (parsed.config.outputDirectory.empty()) {
        parsed.config.outputDirectory = std::filesystem::current_path() / "JUCE-Backup-Runs";
    }

    auto backend = makeBackend(parsed.config.dryRun);
    if (backend == nullptr) {
        std::cerr << "error: this build does not include the CUDA WaveMix backend; use --dry-run\n";
        return 2;
    }

    auto telemetry = parsed.config.telemetryEnabled
                         ? (parsed.config.dryRun ? makeSyntheticTelemetry() : makeNvidiaSmiTelemetry())
                         : std::unique_ptr<ITelemetryProvider>{};
    auto logger = std::make_unique<RunLogger>();
    StressEngine engine(std::move(backend), std::move(telemetry), std::move(logger));

    std::signal(SIGINT, handleSignal);
    std::signal(SIGTERM, handleSignal);
    activeEngine.store(&engine);

    std::string error;
    if (!engine.start(parsed.config, error)) {
        activeEngine.store(nullptr);
        std::cerr << "error: " << error << '\n';
        return 2;
    }

    std::uint64_t lastWindow = static_cast<std::uint64_t>(-1);
    while (engine.isRunning()) {
        const auto snapshot = engine.snapshot();
        if (snapshot.completedWindows != lastWindow) {
            lastWindow = snapshot.completedWindows;
            std::cout << "\rstate=" << snapshot.stateText
                      << " elapsed=" << static_cast<long long>(snapshot.elapsedSeconds) << "s"
                      << " remaining=" << static_cast<long long>(snapshot.remainingSeconds) << "s"
                      << " target=" << snapshot.targetLoadPercent << "%"
                      << " active=" << snapshot.lastActiveMilliseconds << "ms";
            if (snapshot.telemetry.available) {
                std::cout << " gpu=" << snapshot.telemetry.utilizationPercent << "%"
                          << " temp=" << snapshot.telemetry.temperatureC << "C"
                          << " power=" << snapshot.telemetry.powerWatts << "W";
            }
            std::cout << std::flush;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }
    engine.wait();
    activeEngine.store(nullptr);

    const auto finalSnapshot = engine.snapshot();
    std::cout << '\n' << finalSnapshot.stateText << '\n';
    if (finalSnapshot.state == EngineState::Error) {
        std::cerr << "error: " << finalSnapshot.error << '\n';
        return 2;
    }
    return 0;
}
