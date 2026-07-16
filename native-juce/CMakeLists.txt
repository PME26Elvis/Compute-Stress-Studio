cmake_minimum_required(VERSION 3.24)

project(GPUStressJUCEBackup VERSION 1.0.0 LANGUAGES CXX)

option(GPU_STRESS_ENABLE_CUDA "Build the real CUDA WaveMix backend" ON)
option(GPU_STRESS_BUILD_GUI "Build the JUCE GUI and hidden background application" ON)
option(GPU_STRESS_BUILD_TESTS "Build unit and integration tests" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(FetchContent)

if(GPU_STRESS_ENABLE_CUDA)
    enable_language(CUDA)
    find_package(CUDAToolkit REQUIRED)
    set(CMAKE_CUDA_STANDARD 17)
    set(CMAKE_CUDA_STANDARD_REQUIRED ON)
    set(CMAKE_CUDA_ARCHITECTURES 61 75 86 89)
    set(CMAKE_CUDA_RUNTIME_LIBRARY Static)
endif()

add_library(gpu_stress_backup_core STATIC
    src/AppConfig.cpp
    src/DutyScheduler.cpp
    src/RunLogger.cpp
    src/StressEngine.cpp
    src/SyntheticStressBackend.cpp
    src/NvidiaSmiTelemetry.cpp
)

target_include_directories(gpu_stress_backup_core PUBLIC include)
target_compile_features(gpu_stress_backup_core PUBLIC cxx_std_20)
target_compile_definitions(gpu_stress_backup_core PUBLIC
    GPU_STRESS_DEFAULT_DURATION_SECONDS=345600
    GPU_STRESS_DEFAULT_LOAD_PERCENT=87
)

if(MSVC)
    target_compile_options(gpu_stress_backup_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(gpu_stress_backup_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

if(GPU_STRESS_ENABLE_CUDA)
    add_library(gpu_stress_backup_cuda STATIC src/CudaWaveMixBackend.cu)
    target_include_directories(gpu_stress_backup_cuda PUBLIC include)
    target_link_libraries(gpu_stress_backup_cuda PUBLIC gpu_stress_backup_core CUDA::cudart_static)
    target_compile_definitions(gpu_stress_backup_cuda PUBLIC GPU_STRESS_HAS_CUDA=1)
    set_target_properties(gpu_stress_backup_cuda PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
        CUDA_RESOLVE_DEVICE_SYMBOLS ON
    )
else()
    add_library(gpu_stress_backup_cuda INTERFACE)
    target_link_libraries(gpu_stress_backup_cuda INTERFACE gpu_stress_backup_core)
    target_compile_definitions(gpu_stress_backup_core PUBLIC GPU_STRESS_HAS_CUDA=0)
endif()

add_executable(GPUStressJUCECLI src/CliMain.cpp)
target_link_libraries(GPUStressJUCECLI PRIVATE gpu_stress_backup_core gpu_stress_backup_cuda)
set_target_properties(GPUStressJUCECLI PROPERTIES OUTPUT_NAME "GPU-Stress-JUCE-CLI")

if(GPU_STRESS_BUILD_GUI)
    FetchContent_Declare(
        JUCE
        GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
        GIT_TAG 8.0.14
        GIT_SHALLOW TRUE
    )
    FetchContent_MakeAvailable(JUCE)

    juce_add_gui_app(GPUStressJUCE
        PRODUCT_NAME "GPU Stress JUCE Backup"
        COMPANY_NAME "PME26Elvis"
        BUNDLE_ID "com.pme26elvis.gpustressjucebackup"
        NEEDS_CURL FALSE
        NEEDS_WEB_BROWSER FALSE
    )

    target_sources(GPUStressJUCE PRIVATE
        src/JuceApplication.cpp
        src/MainComponent.cpp
        src/MainWindow.cpp
        src/BackgroundRunner.cpp
    )
    target_include_directories(GPUStressJUCE PRIVATE include)
    target_link_libraries(GPUStressJUCE PRIVATE
        gpu_stress_backup_core
        gpu_stress_backup_cuda
        juce::juce_gui_extra
        juce::juce_gui_basics
        juce::juce_graphics
        juce::juce_events
        juce::juce_core
    )
    target_compile_definitions(GPUStressJUCE PRIVATE
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_APPLICATION_NAME_STRING="$<TARGET_PROPERTY:GPUStressJUCE,JUCE_PRODUCT_NAME>"
        JUCE_APPLICATION_VERSION_STRING="${PROJECT_VERSION}"
    )
    set_target_properties(GPUStressJUCE PROPERTIES OUTPUT_NAME "GPU-Stress-JUCE")
endif()

if(GPU_STRESS_BUILD_TESTS)
    enable_testing()
    add_executable(GPUStressJUCETests
        tests/TestMain.cpp
        tests/AppConfigTests.cpp
        tests/DutySchedulerTests.cpp
        tests/RunLoggerTests.cpp
        tests/StressEngineTests.cpp
    )
    target_include_directories(GPUStressJUCETests PRIVATE include tests)
    target_link_libraries(GPUStressJUCETests PRIVATE gpu_stress_backup_core)
    add_test(NAME gpu-stress-juce-core-tests COMMAND GPUStressJUCETests)
endif()
