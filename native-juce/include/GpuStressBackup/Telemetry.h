#pragma once

#include <memory>
#include <string>

namespace gpu_stress_backup {

struct TelemetrySample {
    bool available = false;
    std::string deviceName;
    double utilizationPercent = 0.0;
    double temperatureC = 0.0;
    double powerWatts = 0.0;
    double memoryUsedMiB = 0.0;
    double memoryTotalMiB = 0.0;
    std::string error;
};

class ITelemetryProvider {
public:
    virtual ~ITelemetryProvider() = default;
    [[nodiscard]] virtual TelemetrySample sample(int deviceIndex) = 0;
};

[[nodiscard]] std::unique_ptr<ITelemetryProvider> makeNvidiaSmiTelemetry();
[[nodiscard]] std::unique_ptr<ITelemetryProvider> makeSyntheticTelemetry();

}  // namespace gpu_stress_backup
