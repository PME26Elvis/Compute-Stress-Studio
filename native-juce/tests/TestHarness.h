#pragma once

#include <cmath>
#include <functional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace gpu_stress_backup::tests {

using TestFunction = void (*)();

inline std::vector<std::pair<std::string, TestFunction>>& registry() {
    static std::vector<std::pair<std::string, TestFunction>> tests;
    return tests;
}

class Registrar {
public:
    Registrar(std::string name, TestFunction function) {
        registry().emplace_back(std::move(name), function);
    }
};

inline void require(bool condition,
                    const char* expression,
                    const char* file,
                    int line) {
    if (!condition) {
        std::ostringstream stream;
        stream << file << ':' << line << " requirement failed: " << expression;
        throw std::runtime_error(stream.str());
    }
}

inline void requireNear(double actual,
                        double expected,
                        double tolerance,
                        const char* file,
                        int line) {
    if (std::abs(actual - expected) > tolerance) {
        std::ostringstream stream;
        stream << file << ':' << line << " expected " << expected << " +/- " << tolerance
               << ", got " << actual;
        throw std::runtime_error(stream.str());
    }
}

}  // namespace gpu_stress_backup::tests

#define GPU_TEST_JOIN_INNER(a, b) a##b
#define GPU_TEST_JOIN(a, b) GPU_TEST_JOIN_INNER(a, b)
#define GPU_TEST_CASE(name)                                                                    \
    static void GPU_TEST_JOIN(gpuTestFunction_, __LINE__)();                                   \
    static ::gpu_stress_backup::tests::Registrar GPU_TEST_JOIN(gpuTestRegistrar_, __LINE__)(   \
        name, &GPU_TEST_JOIN(gpuTestFunction_, __LINE__));                                     \
    static void GPU_TEST_JOIN(gpuTestFunction_, __LINE__)()
#define GPU_REQUIRE(expression)                                                                 \
    ::gpu_stress_backup::tests::require(static_cast<bool>(expression), #expression, __FILE__,  \
                                        __LINE__)
#define GPU_REQUIRE_NEAR(actual, expected, tolerance)                                           \
    ::gpu_stress_backup::tests::requireNear((actual), (expected), (tolerance), __FILE__,        \
                                            __LINE__)
