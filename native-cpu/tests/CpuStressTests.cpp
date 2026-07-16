#include "ComputeStressCpu/Config.h"
#include "ComputeStressCpu/Engine.h"

#include <atomic>
#include <cassert>
#include <chrono>
#include <thread>
#include <vector>

int main() {
    using namespace std::chrono_literals;
    using compute_stress_cpu::Options;

    assert(compute_stress_cpu::recommended_worker_count(1) == 1);
    assert(compute_stress_cpu::recommended_worker_count(8) == 7);
    assert(compute_stress_cpu::recommended_worker_count(128) == 64);

    const auto parsed = compute_stress_cpu::parse_options(
        {"--duration", "60", "--load", "65", "--threads", "7"});
    assert(parsed.ok);
    assert(parsed.options.duration == 60s);
    assert(parsed.options.load_percent == 65.0);
    assert(parsed.options.threads == 7);

    assert(!compute_stress_cpu::parse_options({"--load", "101"}).ok);
    assert(!compute_stress_cpu::parse_options({"--threads", "0"}).ok);
    assert(!compute_stress_cpu::parse_options({"--unknown", "1"}).ok);

    Options options;
    options.duration = 10s;
    options.load_percent = 25.0;
    options.threads = 2;
    std::atomic_bool stop_requested{false};

    const auto started = std::chrono::steady_clock::now();
    std::thread engine([&] { compute_stress_cpu::run_engine(options, stop_requested); });
    std::this_thread::sleep_for(150ms);
    stop_requested.store(true, std::memory_order_relaxed);
    engine.join();
    const auto elapsed = std::chrono::steady_clock::now() - started;

    assert(elapsed < 2s);
    return 0;
}
