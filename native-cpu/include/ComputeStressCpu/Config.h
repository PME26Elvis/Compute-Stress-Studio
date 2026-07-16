#pragma once

#include <chrono>
#include <cstddef>
#include <string>
#include <vector>

namespace compute_stress_cpu {

struct Options {
    std::chrono::seconds duration{3600};
    double load_percent{65.0};
    std::size_t threads{1};
    bool self_test{false};
};

struct ParseResult {
    Options options{};
    bool ok{true};
};

std::size_t recommended_worker_count(unsigned int logical_processors) noexcept;
ParseResult parse_options(const std::vector<std::string>& arguments) noexcept;

}  // namespace compute_stress_cpu
