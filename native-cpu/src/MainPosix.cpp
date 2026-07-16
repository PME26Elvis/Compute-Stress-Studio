#include "ComputeStressCpu/Config.h"
#include "ComputeStressCpu/Engine.h"

#include <atomic>
#include <csignal>
#include <string>
#include <vector>

namespace {

std::atomic_bool* active_stop_flag = nullptr;

void handle_signal(int) {
    if (active_stop_flag != nullptr) {
        active_stop_flag->store(true, std::memory_order_relaxed);
    }
}

}  // namespace

int main(int argc, char** argv) {
    std::vector<std::string> arguments;
    arguments.reserve(static_cast<std::size_t>(argc > 1 ? argc - 1 : 0));
    for (int index = 1; index < argc; ++index) {
        arguments.emplace_back(argv[index]);
    }

    const auto parsed = compute_stress_cpu::parse_options(arguments);
    if (!parsed.ok) {
        return 2;
    }

    compute_stress_cpu::lower_process_priority();
    std::atomic_bool stop_requested{false};
    active_stop_flag = &stop_requested;
    std::signal(SIGINT, handle_signal);
    std::signal(SIGTERM, handle_signal);
    compute_stress_cpu::run_engine(parsed.options, stop_requested);
    active_stop_flag = nullptr;
    return 0;
}
