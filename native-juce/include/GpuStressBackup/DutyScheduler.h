#pragma once

namespace gpu_stress_backup {

class DutyScheduler {
public:
    DutyScheduler(double loadPercent, int windowMilliseconds);

    void setLoadPercent(double loadPercent);
    [[nodiscard]] double loadPercent() const noexcept;
    [[nodiscard]] int windowMilliseconds() const noexcept;
    [[nodiscard]] double activeBudgetMilliseconds() const noexcept;
    [[nodiscard]] double idleBudgetMilliseconds(double measuredActiveMilliseconds) const noexcept;

private:
    double loadPercent_ = 0.0;
    int windowMilliseconds_ = 200;
};

}  // namespace gpu_stress_backup
