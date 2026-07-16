#include "GpuStressBackup/RunLogger.h"

#include <chrono>
#include <iomanip>
#include <sstream>

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

namespace gpu_stress_backup {

RunLogger::~RunLogger() {
    close();
}

bool RunLogger::open(const std::filesystem::path& directory,
                     const AppConfig& config,
                     std::string& error) {
    std::scoped_lock lock(mutex_);
    if (opened_) {
        error = "logger is already open";
        return false;
    }

    std::error_code filesystemError;
    std::filesystem::create_directories(directory, filesystemError);
    if (filesystemError) {
        error = "cannot create output directory: " + filesystemError.message();
        return false;
    }

    directory_ = directory;
    logPath_ = directory_ / "gpu-stress-juce-console.log";
    csvPath_ = directory_ / "gpu-stress-juce-telemetry.csv";
    pidPath_ = directory_ / "gpu-stress-juce.pid";

    logStream_.open(logPath_, std::ios::out | std::ios::app);
    csvStream_.open(csvPath_, std::ios::out | std::ios::trunc);
    if (!logStream_ || !csvStream_) {
        error = "cannot open log or CSV output";
        logStream_.close();
        csvStream_.close();
        return false;
    }

    {
        std::ofstream pidStream(pidPath_, std::ios::out | std::ios::trunc);
        if (!pidStream) {
            error = "cannot write PID file";
            logStream_.close();
            csvStream_.close();
            return false;
        }
        pidStream << currentProcessId() << '\n';
    }

    csvStream_ << "timestamp,state,elapsed_seconds,remaining_seconds,target_load_percent,"
                  "active_ms,idle_ms,gpu_name,gpu_util_percent,temperature_c,power_watts,"
                  "memory_used_mib,memory_total_mib,strategy,allocated_bytes,kernel_iterations,"
                  "calibrated_kernel_ms,error\n";
    csvStream_.flush();

    logStream_ << '[' << timestamp() << "] started: duration=" << config.durationSeconds
               << "s load=" << config.loadPercent << "% memory=" << config.memoryMiB
               << "MiB device=" << config.deviceIndex << " strategy=WaveMix\n";
    logStream_.flush();
    opened_ = true;
    return true;
}

void RunLogger::writeMessage(const std::string& message) {
    std::scoped_lock lock(mutex_);
    if (!opened_) {
        return;
    }
    logStream_ << '[' << timestamp() << "] " << message << '\n';
    logStream_.flush();
}

void RunLogger::writeSnapshot(const EngineSnapshot& snapshot) {
    std::scoped_lock lock(mutex_);
    if (!opened_) {
        return;
    }

    csvStream_ << timestamp() << ','
               << csvEscape(snapshot.stateText) << ','
               << std::fixed << std::setprecision(3) << snapshot.elapsedSeconds << ','
               << snapshot.remainingSeconds << ','
               << snapshot.targetLoadPercent << ','
               << snapshot.lastActiveMilliseconds << ','
               << snapshot.lastIdleMilliseconds << ','
               << csvEscape(snapshot.telemetry.deviceName) << ','
               << snapshot.telemetry.utilizationPercent << ','
               << snapshot.telemetry.temperatureC << ','
               << snapshot.telemetry.powerWatts << ','
               << snapshot.telemetry.memoryUsedMiB << ','
               << snapshot.telemetry.memoryTotalMiB << ','
               << csvEscape(snapshot.backend.strategyName) << ','
               << snapshot.backend.allocatedBytes << ','
               << snapshot.backend.calibratedIterations << ','
               << snapshot.backend.calibratedKernelMs << ','
               << csvEscape(snapshot.error) << '\n';
    csvStream_.flush();
}

void RunLogger::close() noexcept {
    std::scoped_lock lock(mutex_);
    if (!opened_) {
        return;
    }
    logStream_ << '[' << timestamp() << "] logger closed\n";
    logStream_.flush();
    csvStream_.flush();
    logStream_.close();
    csvStream_.close();
    std::error_code ignored;
    std::filesystem::remove(pidPath_, ignored);
    opened_ = false;
}

std::filesystem::path RunLogger::directory() const {
    std::scoped_lock lock(mutex_);
    return directory_;
}

std::filesystem::path RunLogger::logPath() const {
    std::scoped_lock lock(mutex_);
    return logPath_;
}

std::filesystem::path RunLogger::csvPath() const {
    std::scoped_lock lock(mutex_);
    return csvPath_;
}

std::filesystem::path RunLogger::pidPath() const {
    std::scoped_lock lock(mutex_);
    return pidPath_;
}

std::string RunLogger::timestamp() {
    const auto now = std::chrono::system_clock::now();
    const auto time = std::chrono::system_clock::to_time_t(now);
    std::tm local{};
#ifdef _WIN32
    localtime_s(&local, &time);
#else
    localtime_r(&time, &local);
#endif
    std::ostringstream stream;
    stream << std::put_time(&local, "%Y-%m-%d %H:%M:%S");
    return stream.str();
}

unsigned long RunLogger::currentProcessId() {
#ifdef _WIN32
    return static_cast<unsigned long>(GetCurrentProcessId());
#else
    return static_cast<unsigned long>(getpid());
#endif
}

std::string RunLogger::csvEscape(const std::string& value) {
    std::string escaped;
    escaped.reserve(value.size() + 2);
    escaped.push_back('"');
    for (char character : value) {
        if (character == '"') {
            escaped.push_back('"');
        }
        escaped.push_back(character);
    }
    escaped.push_back('"');
    return escaped;
}

}  // namespace gpu_stress_backup
