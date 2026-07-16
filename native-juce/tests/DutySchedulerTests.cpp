#include "TestHarness.h"

#include "GpuStressBackup/DutyScheduler.h"

using namespace gpu_stress_backup;

GPU_TEST_CASE("87 percent in a 200 ms window requests 174 ms active") {
    DutyScheduler scheduler(87.0, 200);
    GPU_REQUIRE_NEAR(scheduler.activeBudgetMilliseconds(), 174.0, 0.0001);
    GPU_REQUIRE_NEAR(scheduler.idleBudgetMilliseconds(174.0), 26.0, 0.0001);
}

GPU_TEST_CASE("load values are clamped") {
    DutyScheduler low(-25.0, 200);
    DutyScheduler high(150.0, 200);
    GPU_REQUIRE_NEAR(low.activeBudgetMilliseconds(), 0.0, 0.0001);
    GPU_REQUIRE_NEAR(high.activeBudgetMilliseconds(), 200.0, 0.0001);
}

GPU_TEST_CASE("kernel overshoot never creates negative sleep") {
    DutyScheduler scheduler(50.0, 100);
    GPU_REQUIRE_NEAR(scheduler.idleBudgetMilliseconds(115.0), 0.0, 0.0001);
}

GPU_TEST_CASE("load may be changed without rebuilding scheduler") {
    DutyScheduler scheduler(20.0, 250);
    scheduler.setLoadPercent(80.0);
    GPU_REQUIRE_NEAR(scheduler.activeBudgetMilliseconds(), 200.0, 0.0001);
}
