#include "ComputeStressCpu/Config.h"
#include "ComputeStressCpu/Engine.h"

#define NOMINMAX
#include <windows.h>
#include <shellapi.h>

#include <atomic>
#include <string>
#include <vector>

namespace {

std::string narrow(const std::wstring& value) {
    if (value.empty()) {
        return {};
    }
    const int size = WideCharToMultiByte(
        CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    std::string result(static_cast<std::size_t>(size), '\0');
    WideCharToMultiByte(
        CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), size, nullptr, nullptr);
    return result;
}

std::vector<std::string> command_line_arguments() {
    int count = 0;
    LPWSTR* values = CommandLineToArgvW(GetCommandLineW(), &count);
    std::vector<std::string> arguments;
    if (values == nullptr) {
        return arguments;
    }
    for (int index = 1; index < count; ++index) {
        arguments.push_back(narrow(values[index]));
    }
    LocalFree(values);
    return arguments;
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    const auto parsed = compute_stress_cpu::parse_options(command_line_arguments());
    if (!parsed.ok) {
        return 2;
    }

    compute_stress_cpu::lower_process_priority();
    std::atomic_bool stop_requested{false};
    compute_stress_cpu::run_engine(parsed.options, stop_requested);
    return 0;
}
