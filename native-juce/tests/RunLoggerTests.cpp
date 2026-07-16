#include "TestHarness.h"

#include "GpuStressBackup/RunLogger.h"

#include <chrono>
#include <filesystem>
#include <fstream>
#include <sstream>

using namespace gpu_stress_backup;

namespace {

std::filesystem::path makeTemporaryDirectory() {
    const auto suffix = std::chrono::steady_clock::now().time_since_epoch().count();
    return std::filesystem::temp_directory_path() /
           ("gpu-stress-juce-tests-" + std::to_string(suffix));
}

std::string readAll(const std::filesystem::path& path) {
    std::ifstream stream(path);
    std::ostringstream output;
    output << stream.rdbuf();
    return output.str();
}

}  // namespace

GPU_TEST_CASE("logger creates log CSV and PID then removes PID on close") {
    const auto directory = makeTemporaryDirectory();
    AppConfig config;
    RunLogger logger;
    std::string error;
    GPU_REQUIRE(logger.open(directory, config, error));
    GPU_REQUIRE(std::filesystem::exists(logger.logPath()));
    GPU_REQUIRE(std::filesystem::exists(logger.csvPath()));
    GPU_REQUIRE(std::filesystem::exists(logger.pidPath()));

    EngineSnapshot snapshot;
    snapshot.state = EngineState::Running;
    snapshot.stateText = "Running";
    snapshot.elapsedSeconds = 1.25;
    snapshot.remainingSeconds = 9.75;
    snapshot.targetLoadPercent = 87.0;
    snapshot.backend.strategyName = "WaveMix";
    snapshot.backend.deviceName = "Quadro P2200";
    snapshot.telemetry.available = true;
    snapshot.telemetry.deviceName = "Quadro P2200";
    snapshot.telemetry.utilizationPercent = 87.0;
    logger.writeMessage("test message");
    logger.writeSnapshot(snapshot);

    const auto logPath = logger.logPath();
    const auto csvPath = logger.csvPath();
    const auto pidPath = logger.pidPath();
    logger.close();

    GPU_REQUIRE(!std::filesystem::exists(pidPath));
    GPU_REQUIRE(readAll(logPath).find("test message") != std::string::npos);
    const auto csv = readAll(csvPath);
    GPU_REQUIRE(csv.find("timestamp,state") != std::string::npos);
    GPU_REQUIRE(csv.find("WaveMix") != std::string::npos);
    GPU_REQUIRE(csv.find("Quadro P2200") != std::string::npos);

    std::error_code ignored;
    std::filesystem::remove_all(directory, ignored);
}
