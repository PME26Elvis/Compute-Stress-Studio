#include "TestHarness.h"

#include <exception>
#include <iostream>

int main() {
    int failures = 0;
    for (const auto& [name, function] : gpu_stress_backup::tests::registry()) {
        try {
            function();
            std::cout << "[PASS] " << name << '\n';
        } catch (const std::exception& exception) {
            ++failures;
            std::cerr << "[FAIL] " << name << ": " << exception.what() << '\n';
        } catch (...) {
            ++failures;
            std::cerr << "[FAIL] " << name << ": unknown exception\n";
        }
    }

    std::cout << gpu_stress_backup::tests::registry().size() << " tests, "
              << failures << " failures\n";
    return failures == 0 ? 0 : 1;
}
