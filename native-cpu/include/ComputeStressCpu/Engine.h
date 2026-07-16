#pragma once

#include "ComputeStressCpu/Config.h"

#include <atomic>

namespace compute_stress_cpu {

void lower_process_priority() noexcept;
void run_engine(const Options& options, std::atomic_bool& stop_requested);

}  // namespace compute_stress_cpu
