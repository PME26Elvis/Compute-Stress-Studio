#include "ComputeStressCpu/Config.h"

#include <algorithm>
#include <charconv>
#include <cmath>
#include <limits>
#include <thread>

namespace compute_stress_cpu {
namespace {

template <typename T>
bool parse_integer(const std::string& text, T& value) noexcept {
    const auto* begin = text.data();
    const auto* end = text.data() + text.size();
    const auto result = std::from_chars(begin, end, value);
    return result.ec == std::errc{} && result.ptr == end;
}

bool parse_double(const std::string& text, double& value) noexcept {
    try {
        std::size_t consumed = 0;
        value = std::stod(text, &consumed);
        return consumed == text.size() && std::isfinite(value);
    } catch (...) {
        return false;
    }
}

}  // namespace

std::size_t recommended_worker_count(const unsigned int logical_processors) noexcept {
    if (logical_processors <= 1) {
        return 1;
    }
    return std::clamp<std::size_t>(logical_processors - 1, 1, 64);
}

ParseResult parse_options(const std::vector<std::string>& arguments) noexcept {
    ParseResult result;
    result.options.threads = recommended_worker_count(std::thread::hardware_concurrency());

    for (std::size_t index = 0; index < arguments.size(); ++index) {
        const auto& argument = arguments[index];
        if (argument == "--self-test") {
            result.options.self_test = true;
            result.options.duration = std::chrono::seconds{1};
            result.options.load_percent = 10.0;
            result.options.threads = 1;
            continue;
        }

        if (index + 1 >= arguments.size()) {
            result.ok = false;
            return result;
        }
        const auto& value = arguments[++index];

        if (argument == "--duration") {
            long long seconds = 0;
            if (!parse_integer(value, seconds) || seconds < 1 || seconds > 14LL * 24LL * 60LL * 60LL) {
                result.ok = false;
                return result;
            }
            result.options.duration = std::chrono::seconds{seconds};
        } else if (argument == "--load") {
            double load = 0.0;
            if (!parse_double(value, load) || load < 0.0 || load > 100.0) {
                result.ok = false;
                return result;
            }
            result.options.load_percent = load;
        } else if (argument == "--threads") {
            unsigned long long threads = 0;
            if (!parse_integer(value, threads) || threads < 1 || threads > 64) {
                result.ok = false;
                return result;
            }
            result.options.threads = static_cast<std::size_t>(threads);
        } else {
            result.ok = false;
            return result;
        }
    }

    return result;
}

}  // namespace compute_stress_cpu
