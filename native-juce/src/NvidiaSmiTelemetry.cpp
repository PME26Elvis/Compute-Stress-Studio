#include "GpuStressBackup/Telemetry.h"

#include <array>
#include <cstdio>
#include <cstdlib>
#include <sstream>
#include <string>
#include <vector>

namespace gpu_stress_backup {
namespace {

#ifdef _WIN32
#define GPU_STRESS_POPEN _popen
#define GPU_STRESS_PCLOSE _pclose
#else
#define GPU_STRESS_POPEN popen
#define GPU_STRESS_PCLOSE pclose
#endif

std::string trim(std::string value) {
    const auto first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) {
        return {};
    }
    const auto last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

std::vector<std::string> splitCsv(const std::string& line) {
    std::vector<std::string> fields;
    std::stringstream stream(line);
    std::string field;
    while (std::getline(stream, field, ',')) {
        fields.push_back(trim(field));
    }
    return fields;
}

double parseDouble(const std::string& value) {
    char* end = nullptr;
    const auto parsed = std::strtod(value.c_str(), &end);
    return end != value.c_str() ? parsed : 0.0;
}

class NvidiaSmiTelemetry final : public ITelemetryProvider {
public:
    TelemetrySample sample(int deviceIndex) override {
        const auto command =
            "nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,power.draw,"
            "memory.used,memory.total --format=csv,noheader,nounits --id=" +
            std::to_string(deviceIndex) + " 2>&1";

        FILE* pipe = GPU_STRESS_POPEN(command.c_str(), "r");
        if (pipe == nullptr) {
            return unavailable("cannot start nvidia-smi");
        }

        std::array<char, 1024> buffer{};
        std::string output;
        while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
            output += buffer.data();
        }
        const int exitCode = GPU_STRESS_PCLOSE(pipe);
        if (exitCode != 0) {
            return unavailable(trim(output.empty() ? "nvidia-smi failed" : output));
        }

        const auto firstLineEnd = output.find_first_of("\r\n");
        const auto fields = splitCsv(output.substr(0, firstLineEnd));
        if (fields.size() < 6) {
            return unavailable("unexpected nvidia-smi output: " + trim(output));
        }

        TelemetrySample result;
        result.available = true;
        result.deviceName = fields[0];
        result.utilizationPercent = parseDouble(fields[1]);
        result.temperatureC = parseDouble(fields[2]);
        result.powerWatts = parseDouble(fields[3]);
        result.memoryUsedMiB = parseDouble(fields[4]);
        result.memoryTotalMiB = parseDouble(fields[5]);
        return result;
    }

private:
    static TelemetrySample unavailable(std::string message) {
        TelemetrySample result;
        result.available = false;
        result.error = std::move(message);
        return result;
    }
};

}  // namespace

std::unique_ptr<ITelemetryProvider> makeNvidiaSmiTelemetry() {
    return std::make_unique<NvidiaSmiTelemetry>();
}

}  // namespace gpu_stress_backup
