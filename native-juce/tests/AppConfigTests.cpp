#include "TestHarness.h"

#include "GpuStressBackup/AppConfig.h"

using namespace gpu_stress_backup;

GPU_TEST_CASE("personal defaults are 96 hours and 87 percent") {
    const auto parsed = parseArguments({});
    GPU_REQUIRE(parsed.ok);
    GPU_REQUIRE(parsed.config.durationSeconds == 345600);
    GPU_REQUIRE_NEAR(parsed.config.loadPercent, 87.0, 0.0001);
    GPU_REQUIRE(parsed.config.memoryMiB == 192);
    GPU_REQUIRE(parsed.config.temperatureLimitC == 85);
}

GPU_TEST_CASE("explicit command line values override defaults") {
    const auto parsed = parseArguments({"--duration", "7200", "--load=75", "--memory-mib",
                                        "256", "--device", "1", "--temp-limit", "80",
                                        "--window-ms", "250", "--kernel-ms", "12",
                                        "--output-dir", "D:/runs", "--background"});
    GPU_REQUIRE(parsed.ok);
    GPU_REQUIRE(parsed.config.durationSeconds == 7200);
    GPU_REQUIRE_NEAR(parsed.config.loadPercent, 75.0, 0.0001);
    GPU_REQUIRE(parsed.config.memoryMiB == 256);
    GPU_REQUIRE(parsed.config.deviceIndex == 1);
    GPU_REQUIRE(parsed.config.temperatureLimitC == 80);
    GPU_REQUIRE(parsed.config.dutyWindowMs == 250);
    GPU_REQUIRE(parsed.config.targetKernelMs == 12);
    GPU_REQUIRE(parsed.config.background);
    GPU_REQUIRE(parsed.config.outputDirectory == std::filesystem::path("D:/runs"));
}

GPU_TEST_CASE("invalid load is rejected") {
    const auto parsed = parseArguments({"--load", "101"});
    GPU_REQUIRE(!parsed.ok);
    GPU_REQUIRE(parsed.error.find("load") != std::string::npos);
}

GPU_TEST_CASE("unknown arguments are rejected") {
    const auto parsed = parseArguments({"--not-a-real-option"});
    GPU_REQUIRE(!parsed.ok);
    GPU_REQUIRE(parsed.error.find("unknown") != std::string::npos);
}

GPU_TEST_CASE("quoted command line paths remain one token") {
    const auto tokens = splitCommandLine("--output-dir \"D:/GPU Stress Runs\" --dry-run");
    GPU_REQUIRE(tokens.size() == 3);
    GPU_REQUIRE(tokens[1] == "D:/GPU Stress Runs");
    GPU_REQUIRE(tokens[2] == "--dry-run");
}
