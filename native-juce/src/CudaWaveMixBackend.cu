#include "GpuStressBackup/StressBackend.h"

#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <memory>
#include <sstream>

namespace gpu_stress_backup {
namespace {

constexpr int kThreadsPerBlock = 256;
constexpr std::size_t kMiB = 1024U * 1024U;

__device__ __forceinline__ std::uint32_t xorshift32(std::uint32_t value) {
    value ^= value << 13U;
    value ^= value >> 17U;
    value ^= value << 5U;
    return value;
}

__global__ void waveMixKernel(float4* buffer,
                              std::size_t elementCount,
                              int iterations,
                              std::uint32_t launchSeed) {
    extern __shared__ float sharedValues[];
    const unsigned int lane = threadIdx.x;
    const std::size_t globalIndex =
        static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    const std::size_t localIndex = globalIndex % elementCount;

    float4 value = buffer[localIndex];
    std::uint32_t state = launchSeed ^ static_cast<std::uint32_t>(globalIndex * 747796405ULL);
    sharedValues[lane] = value.x + static_cast<float>(lane) * 0.0009765625f;
    __syncthreads();

    for (int iteration = 0; iteration < iterations; ++iteration) {
        state = xorshift32(state + static_cast<std::uint32_t>(iteration + 1));
        const unsigned int sharedIndex =
            (lane * 37U + state + static_cast<unsigned int>(iteration * 11)) & 255U;
        const float sharedInput = sharedValues[sharedIndex];

        value.x = fmaf(value.x, 1.0000001192092896f, value.y + sharedInput * 0.0001220703125f);
        value.y = fmaf(value.y, 0.9999999403953552f, value.z - sharedInput * 0.00006103515625f);
        value.z = fmaf(value.z, 1.0000002384185791f, value.w + value.x * 0.000030517578125f);
        value.w = fmaf(value.w, 0.9999998807907104f, value.x - value.y * 0.0000152587890625f);

        if ((iteration & 7) == 0) {
            const std::size_t neighbourIndex =
                (localIndex + static_cast<std::size_t>(state)) % elementCount;
            const float4 neighbour = buffer[neighbourIndex];
            value.x += neighbour.z * 0.000244140625f;
            value.y -= neighbour.w * 0.0001220703125f;
            value.z += neighbour.x * 0.00006103515625f;
            value.w -= neighbour.y * 0.000030517578125f;
        }

        if ((iteration & 15) == 15) {
            sharedValues[lane] = value.x + value.z;
            __syncthreads();
        }
    }

    buffer[localIndex] = value;
}

std::string cudaErrorMessage(const char* operation, cudaError_t error) {
    std::ostringstream stream;
    stream << operation << " failed: " << cudaGetErrorString(error)
           << " (CUDA error " << static_cast<int>(error) << ')';
    return stream.str();
}

class CudaWaveMixBackend final : public IStressBackend {
public:
    ~CudaWaveMixBackend() override {
        shutdown();
    }

    bool initialize(const AppConfig& config, std::string& error) override {
        shutdown();
        config_ = config;

        if (const auto status = cudaSetDevice(config.deviceIndex); status != cudaSuccess) {
            error = cudaErrorMessage("cudaSetDevice", status);
            return false;
        }

        cudaDeviceProp properties{};
        if (const auto status = cudaGetDeviceProperties(&properties, config.deviceIndex);
            status != cudaSuccess) {
            error = cudaErrorMessage("cudaGetDeviceProperties", status);
            return false;
        }

        std::size_t freeBytes = 0;
        std::size_t totalBytes = 0;
        if (const auto status = cudaMemGetInfo(&freeBytes, &totalBytes); status != cudaSuccess) {
            error = cudaErrorMessage("cudaMemGetInfo", status);
            return false;
        }

        const std::size_t requestedBytes = static_cast<std::size_t>(config.memoryMiB) * kMiB;
        const std::size_t reserveBytes = std::max<std::size_t>(256U * kMiB, totalBytes / 10U);
        const std::size_t safeAvailable = freeBytes > reserveBytes ? freeBytes - reserveBytes : freeBytes / 2U;
        const std::size_t allocationBytes = std::min(requestedBytes, safeAvailable);
        if (allocationBytes < 32U * kMiB) {
            error = "not enough free VRAM after preserving the driver/display reserve";
            return false;
        }

        elementCount_ = allocationBytes / sizeof(float4);
        allocatedBytes_ = elementCount_ * sizeof(float4);
        if (const auto status = cudaMalloc(reinterpret_cast<void**>(&buffer_), allocatedBytes_);
            status != cudaSuccess) {
            error = cudaErrorMessage("cudaMalloc", status);
            shutdown();
            return false;
        }
        if (const auto status = cudaMemset(buffer_, 0x3f, allocatedBytes_); status != cudaSuccess) {
            error = cudaErrorMessage("cudaMemset", status);
            shutdown();
            return false;
        }
        if (const auto status = cudaStreamCreateWithFlags(&stream_, cudaStreamNonBlocking);
            status != cudaSuccess) {
            error = cudaErrorMessage("cudaStreamCreateWithFlags", status);
            shutdown();
            return false;
        }
        if (const auto status = cudaEventCreate(&startEvent_); status != cudaSuccess) {
            error = cudaErrorMessage("cudaEventCreate(start)", status);
            shutdown();
            return false;
        }
        if (const auto status = cudaEventCreate(&stopEvent_); status != cudaSuccess) {
            error = cudaErrorMessage("cudaEventCreate(stop)", status);
            shutdown();
            return false;
        }

        blocks_ = std::max(1, properties.multiProcessorCount * 8);
        iterations_ = 128;
        targetKernelMilliseconds_ = static_cast<double>(config.targetKernelMs);

        for (int calibrationPass = 0; calibrationPass < 4; ++calibrationPass) {
            double measured = 0.0;
            if (!launchMeasured(iterations_, measured, error)) {
                shutdown();
                return false;
            }
            if (measured <= 0.01) {
                iterations_ = std::min(iterations_ * 8, 1 << 22);
                continue;
            }
            const double scale = targetKernelMilliseconds_ / measured;
            const int proposed = static_cast<int>(std::lround(iterations_ * scale));
            iterations_ = std::clamp(proposed, 16, 1 << 22);
            calibratedKernelMilliseconds_ = measured;
        }

        double finalMeasurement = 0.0;
        if (!launchMeasured(iterations_, finalMeasurement, error)) {
            shutdown();
            return false;
        }
        calibratedKernelMilliseconds_ = finalMeasurement;

        info_.strategyName = "CUDA WaveMix short-kernel duty scheduler";
        info_.deviceName = properties.name;
        info_.allocatedBytes = allocatedBytes_;
        info_.calibratedIterations = iterations_;
        info_.calibratedKernelMs = calibratedKernelMilliseconds_;
        initialized_ = true;
        return true;
    }

    double runActiveFor(double requestedMilliseconds, std::string& error) override {
        if (!initialized_) {
            error = "CUDA WaveMix backend is not initialized";
            return 0.0;
        }
        if (requestedMilliseconds <= 0.0) {
            return 0.0;
        }

        const auto started = std::chrono::steady_clock::now();
        double elapsedMilliseconds = 0.0;
        while (elapsedMilliseconds < requestedMilliseconds) {
            const auto seed = ++launchSeed_;
            waveMixKernel<<<blocks_, kThreadsPerBlock, kThreadsPerBlock * sizeof(float), stream_>>>(
                buffer_, elementCount_, iterations_, seed);
            if (const auto status = cudaGetLastError(); status != cudaSuccess) {
                error = cudaErrorMessage("waveMixKernel launch", status);
                return elapsedMilliseconds;
            }
            if (const auto status = cudaStreamSynchronize(stream_); status != cudaSuccess) {
                error = cudaErrorMessage("cudaStreamSynchronize", status);
                return elapsedMilliseconds;
            }
            elapsedMilliseconds = std::chrono::duration<double, std::milli>(
                                      std::chrono::steady_clock::now() - started)
                                      .count();
        }
        return elapsedMilliseconds;
    }

    void shutdown() noexcept override {
        initialized_ = false;
        if (stopEvent_ != nullptr) {
            cudaEventDestroy(stopEvent_);
            stopEvent_ = nullptr;
        }
        if (startEvent_ != nullptr) {
            cudaEventDestroy(startEvent_);
            startEvent_ = nullptr;
        }
        if (stream_ != nullptr) {
            cudaStreamDestroy(stream_);
            stream_ = nullptr;
        }
        if (buffer_ != nullptr) {
            cudaFree(buffer_);
            buffer_ = nullptr;
        }
        elementCount_ = 0;
        allocatedBytes_ = 0;
    }

    BackendInfo info() const override {
        auto result = info_;
        result.calibratedIterations = iterations_;
        result.calibratedKernelMs = calibratedKernelMilliseconds_;
        return result;
    }

private:
    bool launchMeasured(int iterations, double& milliseconds, std::string& error) {
        if (const auto status = cudaEventRecord(startEvent_, stream_); status != cudaSuccess) {
            error = cudaErrorMessage("cudaEventRecord(start)", status);
            return false;
        }
        waveMixKernel<<<blocks_, kThreadsPerBlock, kThreadsPerBlock * sizeof(float), stream_>>>(
            buffer_, elementCount_, iterations, ++launchSeed_);
        if (const auto status = cudaGetLastError(); status != cudaSuccess) {
            error = cudaErrorMessage("calibration kernel launch", status);
            return false;
        }
        if (const auto status = cudaEventRecord(stopEvent_, stream_); status != cudaSuccess) {
            error = cudaErrorMessage("cudaEventRecord(stop)", status);
            return false;
        }
        if (const auto status = cudaEventSynchronize(stopEvent_); status != cudaSuccess) {
            error = cudaErrorMessage("cudaEventSynchronize", status);
            return false;
        }
        float measured = 0.0f;
        if (const auto status = cudaEventElapsedTime(&measured, startEvent_, stopEvent_);
            status != cudaSuccess) {
            error = cudaErrorMessage("cudaEventElapsedTime", status);
            return false;
        }
        milliseconds = static_cast<double>(measured);
        return true;
    }

    AppConfig config_;
    float4* buffer_ = nullptr;
    std::size_t elementCount_ = 0;
    std::size_t allocatedBytes_ = 0;
    cudaStream_t stream_ = nullptr;
    cudaEvent_t startEvent_ = nullptr;
    cudaEvent_t stopEvent_ = nullptr;
    int blocks_ = 1;
    int iterations_ = 128;
    double targetKernelMilliseconds_ = 8.0;
    double calibratedKernelMilliseconds_ = 0.0;
    std::uint32_t launchSeed_ = 0x9e3779b9U;
    bool initialized_ = false;
    BackendInfo info_;
};

}  // namespace

std::unique_ptr<IStressBackend> makeCudaWaveMixBackend() {
    return std::make_unique<CudaWaveMixBackend>();
}

}  // namespace gpu_stress_backup
