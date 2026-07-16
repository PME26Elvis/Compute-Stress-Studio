#include "ComputeStressCpu/Engine.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <thread>
#include <vector>

#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <sys/resource.h>
#endif

namespace compute_stress_cpu {
namespace {

std::atomic<double> result_sink{0.0};

void run_worker(const Options& options, std::atomic_bool& stop_requested) {
    using clock = std::chrono::steady_clock;
    constexpr auto window = std::chrono::milliseconds{50};
    const auto active = std::chrono::duration_cast<clock::duration>(
        window * (options.load_percent / 100.0));
    const auto deadline = clock::now() + options.duration;
    double accumulator = 0.6180339887498948;
    std::uint64_t rounds = 0;

    while (!stop_requested.load(std::memory_order_relaxed) && clock::now() < deadline) {
        const auto window_start = clock::now();
        const auto active_deadline = window_start + active;

        while (!stop_requested.load(std::memory_order_relaxed) && clock::now() < active_deadline) {
            accumulator = std::sqrt(accumulator * accumulator + 1.000000119);
            accumulator = std::sin(accumulator + static_cast<double>(rounds & 255U) * 0.0001) *
                              std::cos(accumulator + 0.25) +
                          1.0;
            ++rounds;
        }

        const auto next_window = window_start + window;
        if (!stop_requested.load(std::memory_order_relaxed) && clock::now() < next_window) {
            std::this_thread::sleep_until(next_window);
        }
    }

    result_sink.store(accumulator, std::memory_order_relaxed);
}

}  // namespace

void lower_process_priority() noexcept {
#ifdef _WIN32
    SetPriorityClass(GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS);
#else
    setpriority(PRIO_PROCESS, 0, 5);
#endif
}

void run_engine(const Options& options, std::atomic_bool& stop_requested) {
    std::vector<std::jthread> workers;
    workers.reserve(options.threads);
    for (std::size_t index = 0; index < options.threads; ++index) {
        workers.emplace_back([&options, &stop_requested] { run_worker(options, stop_requested); });
    }

    for (auto& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }
}

}  // namespace compute_stress_cpu
