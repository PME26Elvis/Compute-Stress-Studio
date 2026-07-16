#pragma once

#include "GpuStressBackup/StressEngine.h"

#include <juce_gui_extra/juce_gui_extra.h>

#include <memory>

namespace gpu_stress_backup {

class MainComponent final : public juce::Component, private juce::Timer {
public:
    MainComponent();
    ~MainComponent() override;

    void paint(juce::Graphics& graphics) override;
    void resized() override;

private:
    void timerCallback() override;
    void startRun();
    void stopRun();
    void openOutputDirectory();
    void configureSlider(juce::Slider& slider,
                         double minimum,
                         double maximum,
                         double interval,
                         double value,
                         const juce::String& suffix);
    [[nodiscard]] std::unique_ptr<IStressBackend> createBackend(bool dryRun) const;
    [[nodiscard]] std::filesystem::path outputDirectory() const;

    juce::Label titleLabel_;
    juce::Label subtitleLabel_;
    juce::Label durationLabel_;
    juce::Label loadLabel_;
    juce::Label memoryLabel_;
    juce::Label temperatureLabel_;
    juce::Slider durationHoursSlider_;
    juce::Slider loadSlider_;
    juce::Slider memorySlider_;
    juce::Slider temperatureSlider_;
    juce::ToggleButton dryRunToggle_{"Synthetic dry-run (no GPU)"};
    juce::TextButton startButton_{"Start WaveMix"};
    juce::TextButton stopButton_{"Stop"};
    juce::TextButton outputButton_{"Open output folder"};
    juce::Label stateLabel_;
    juce::Label telemetryLabel_;
    juce::Label backendLabel_;
    juce::Label pathLabel_;
    double progress_ = 0.0;
    juce::ProgressBar progressBar_{progress_};
    std::unique_ptr<StressEngine> engine_;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainComponent)
};

}  // namespace gpu_stress_backup
