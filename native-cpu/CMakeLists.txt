cmake_minimum_required(VERSION 3.22)
project(ComputeStressCpuWorker VERSION 0.2.0 LANGUAGES CXX)

option(COMPUTE_STRESS_CPU_BUILD_TESTS "Build CPU worker tests" ON)

add_library(compute_stress_cpu_core STATIC
    src/Config.cpp
    src/Engine.cpp
)
target_include_directories(compute_stress_cpu_core PUBLIC include)
target_compile_features(compute_stress_cpu_core PUBLIC cxx_std_20)

if(MSVC)
    target_compile_options(compute_stress_cpu_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(compute_stress_cpu_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

if(WIN32)
    add_executable(Compute-Stress-CPU-Worker WIN32 src/MainWindows.cpp)
    target_link_libraries(Compute-Stress-CPU-Worker PRIVATE compute_stress_cpu_core shell32)
else()
    add_executable(Compute-Stress-CPU-Worker src/MainPosix.cpp)
    target_link_libraries(Compute-Stress-CPU-Worker PRIVATE compute_stress_cpu_core)
endif()

target_compile_features(Compute-Stress-CPU-Worker PRIVATE cxx_std_20)

if(COMPUTE_STRESS_CPU_BUILD_TESTS)
    enable_testing()
    add_executable(ComputeStressCpuTests tests/CpuStressTests.cpp)
    target_link_libraries(ComputeStressCpuTests PRIVATE compute_stress_cpu_core)
    target_compile_features(ComputeStressCpuTests PRIVATE cxx_std_20)
    add_test(NAME ComputeStressCpuTests COMMAND ComputeStressCpuTests)
    add_test(NAME ComputeStressCpuWorkerSelfTest COMMAND Compute-Stress-CPU-Worker --self-test)
endif()
