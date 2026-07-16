#pragma once

#include "GpuStressBackup/StressEngine.h"

#include <juce_gui_extra/juce_gui_extra.h>

#include <functional>
#include <memory>

namespace gpu_stress_backup {

class MainComponent final : public juce::Component, private juce::Timer {
public:
    explicit MainComponent(std::function<void()> hideToBackground);
    ~MainComponent() override;

    void paint(juce::Graphics& graphics) override;
    void resized() override;

    void stopRun();
    [[nodiscard]] bool isStressRunning() const noexcept;

private:
    void timerCallback() override;
    void startRun();
    void configureSlider(juce::Slider& slider,
                         double minimum,
                         double maximum,
                         double interval,
                         double value,
                         const juce::String& suffix);
    [[nodiscard]] std::unique_ptr<IStressBackend> createBackend(bool dryRun) const;

    std::function<void()> hideToBackground_;
    juce::Label titleLabel_;
    juce::Label subtitleLabel_;
    juce::Label durationLabel_;
    juce::Label loadLabel_;
    juce::Label memoryLabel_;
    juce::Slider durationHoursSlider_;
    juce::Slider loadSlider_;
    juce::Slider memorySlider_;
    juce::ToggleButton dryRunToggle_{"Synthetic dry-run (no GPU)"};
    juce::TextButton startButton_{"Start WaveMix"};
    juce::TextButton stopButton_{"Stop"};
    juce::TextButton hideButton_{"Hide to background"};
    juce::Label stateLabel_;
    juce::Label backendLabel_;
    juce::Label silentLabel_;
    double progress_ = 0.0;
    juce::ProgressBar progressBar_{progress_};
    std::unique_ptr<StressEngine> engine_;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainComponent)
};

}  // namespace gpu_stress_backup
