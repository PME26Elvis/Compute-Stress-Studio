#include "GpuStressBackup/DutyScheduler.h"

#include <algorithm>

namespace gpu_stress_backup {

DutyScheduler::DutyScheduler(double loadPercent, int windowMilliseconds)
    : loadPercent_(std::clamp(loadPercent, 0.0, 100.0)),
      windowMilliseconds_(std::max(windowMilliseconds, 1)) {}

void DutyScheduler::setLoadPercent(double loadPercent) {
    loadPercent_ = std::clamp(loadPercent, 0.0, 100.0);
}

double DutyScheduler::loadPercent() const noexcept {
    return loadPercent_;
}

int DutyScheduler::windowMilliseconds() const noexcept {
    return windowMilliseconds_;
}

double DutyScheduler::activeBudgetMilliseconds() const noexcept {
    return static_cast<double>(windowMilliseconds_) * loadPercent_ / 100.0;
}

double DutyScheduler::idleBudgetMilliseconds(double measuredActiveMilliseconds) const noexcept {
    return std::max(0.0, static_cast<double>(windowMilliseconds_) - measuredActiveMilliseconds);
}

}  // namespace gpu_stress_backup
