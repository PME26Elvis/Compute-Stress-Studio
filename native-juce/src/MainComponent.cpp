#include "GpuStressBackup/MainComponent.h"

#include "GpuStressBackup/RunLogger.h"
#include "GpuStressBackup/StressBackend.h"
#include "GpuStressBackup/Telemetry.h"

#include <cmath>
#include <filesystem>
#include <iomanip>
#include <sstream>

namespace gpu_stress_backup {
namespace {

void configureCaption(juce::Label& label, const juce::String& text) {
    label.setText(text, juce::dontSendNotification);
    label.setColour(juce::Label::textColourId, juce::Colour(0xffb9c2d0));
    label.setJustificationType(juce::Justification::centredLeft);
}

juce::String formatDuration(double seconds) {
    const auto total = static_cast<long long>(std::max(0.0, seconds));
    const auto hours = total / 3600;
    const auto minutes = (total % 3600) / 60;
    const auto remainingSeconds = total % 60;
    return juce::String(hours) + "h " + juce::String(minutes) + "m " +
           juce::String(remainingSeconds) + "s";
}

}  // namespace

MainComponent::MainComponent() {
    setSize(780, 610);

    titleLabel_.setText("GPU Stress JUCE Backup", juce::dontSendNotification);
    titleLabel_.setFont(juce::Font(juce::FontOptions(28.0f, juce::Font::bold)));
    titleLabel_.setColour(juce::Label::textColourId, juce::Colour(0xfff4f7fb));
    addAndMakeVisible(titleLabel_);

    subtitleLabel_.setText(
        "Independent WaveMix CUDA strategy · Quadro P2200 preset: 96 hours / 87%",
        juce::dontSendNotification);
    subtitleLabel_.setColour(juce::Label::textColourId, juce::Colour(0xff8fa2b8));
    addAndMakeVisible(subtitleLabel_);

    configureCaption(durationLabel_, "Duration");
    configureCaption(loadLabel_, "Target duty load");
    configureCaption(memoryLabel_, "WaveMix VRAM budget");
    configureCaption(temperatureLabel_, "Thermal pause limit");
    addAndMakeVisible(durationLabel_);
    addAndMakeVisible(loadLabel_);
    addAndMakeVisible(memoryLabel_);
    addAndMakeVisible(temperatureLabel_);

    configureSlider(durationHoursSlider_, 0.01, 336.0, 0.25, 96.0, " h");
    configureSlider(loadSlider_, 0.0, 100.0, 1.0, 87.0, " %");
    configureSlider(memorySlider_, 32.0, 4096.0, 16.0, 192.0, " MiB");
    configureSlider(temperatureSlider_, 0.0, 105.0, 1.0, 85.0, " C");

    addAndMakeVisible(durationHoursSlider_);
    addAndMakeVisible(loadSlider_);
    addAndMakeVisible(memorySlider_);
    addAndMakeVisible(temperatureSlider_);

    dryRunToggle_.setColour(juce::ToggleButton::textColourId, juce::Colour(0xffb9c2d0));
    addAndMakeVisible(dryRunToggle_);

    startButton_.setColour(juce::TextButton::buttonColourId, juce::Colour(0xff2166d1));
    startButton_.onClick = [this] { startRun(); };
    stopButton_.setColour(juce::TextButton::buttonColourId, juce::Colour(0xff8c2f39));
    stopButton_.setEnabled(false);
    stopButton_.onClick = [this] { stopRun(); };
    outputButton_.onClick = [this] { openOutputDirectory(); };
    addAndMakeVisible(startButton_);
    addAndMakeVisible(stopButton_);
    addAndMakeVisible(outputButton_);

    stateLabel_.setText("Idle", juce::dontSendNotification);
    stateLabel_.setFont(juce::Font(juce::FontOptions(20.0f, juce::Font::bold)));
    stateLabel_.setColour(juce::Label::textColourId, juce::Colour(0xffe9eef6));
    addAndMakeVisible(stateLabel_);

    telemetryLabel_.setColour(juce::Label::textColourId, juce::Colour(0xffb9c2d0));
    telemetryLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(telemetryLabel_);

    backendLabel_.setColour(juce::Label::textColourId, juce::Colour(0xff8fa2b8));
    backendLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(backendLabel_);

    pathLabel_.setText(juce::String(outputDirectory().string()), juce::dontSendNotification);
    pathLabel_.setColour(juce::Label::textColourId, juce::Colour(0xff71849a));
    pathLabel_.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(pathLabel_);

    progressBar_.setColour(juce::ProgressBar::backgroundColourId, juce::Colour(0xff202631));
    progressBar_.setColour(juce::ProgressBar::foregroundColourId, juce::Colour(0xff3f8cff));
    addAndMakeVisible(progressBar_);

    startTimerHz(5);
}

MainComponent::~MainComponent() {
    stopRun();
    if (engine_ != nullptr) {
        engine_->wait();
    }
}

void MainComponent::paint(juce::Graphics& graphics) {
    juce::ColourGradient gradient(juce::Colour(0xff10141b), 0.0f, 0.0f,
                                  juce::Colour(0xff171e29), 0.0f,
                                  static_cast<float>(getHeight()), false);
    graphics.setGradientFill(gradient);
    graphics.fillAll();

    auto panel = getLocalBounds().reduced(18).toFloat();
    graphics.setColour(juce::Colour(0xff1c2430));
    graphics.fillRoundedRectangle(panel, 14.0f);
    graphics.setColour(juce::Colour(0xff2c3746));
    graphics.drawRoundedRectangle(panel, 14.0f, 1.0f);
}

void MainComponent::resized() {
    auto area = getLocalBounds().reduced(34);
    titleLabel_.setBounds(area.removeFromTop(40));
    subtitleLabel_.setBounds(area.removeFromTop(28));
    area.removeFromTop(14);

    auto placeControl = [&area](juce::Label& label, juce::Slider& slider) {
        auto row = area.removeFromTop(48);
        label.setBounds(row.removeFromLeft(180));
        slider.setBounds(row);
        area.removeFromTop(4);
    };

    placeControl(durationLabel_, durationHoursSlider_);
    placeControl(loadLabel_, loadSlider_);
    placeControl(memoryLabel_, memorySlider_);
    placeControl(temperatureLabel_, temperatureSlider_);

    dryRunToggle_.setBounds(area.removeFromTop(30));
    area.removeFromTop(10);

    auto buttons = area.removeFromTop(42);
    startButton_.setBounds(buttons.removeFromLeft(190));
    buttons.removeFromLeft(10);
    stopButton_.setBounds(buttons.removeFromLeft(120));
    buttons.removeFromLeft(10);
    outputButton_.setBounds(buttons.removeFromLeft(180));
    area.removeFromTop(16);

    stateLabel_.setBounds(area.removeFromTop(32));
    progressBar_.setBounds(area.removeFromTop(24));
    area.removeFromTop(8);
    telemetryLabel_.setBounds(area.removeFromTop(28));
    backendLabel_.setBounds(area.removeFromTop(28));
    pathLabel_.setBounds(area.removeFromTop(26));
}

void MainComponent::timerCallback() {
    if (engine_ == nullptr) {
        return;
    }

    const auto snapshot = engine_->snapshot();
    stateLabel_.setText(juce::String(snapshot.stateText) + " · elapsed " +
                            formatDuration(snapshot.elapsedSeconds) + " · remaining " +
                            formatDuration(snapshot.remainingSeconds),
                        juce::dontSendNotification);

    if (snapshot.telemetry.available) {
        telemetryLabel_.setText(
            juce::String(snapshot.telemetry.deviceName) + " · GPU " +
                juce::String(snapshot.telemetry.utilizationPercent, 1) + "% · " +
                juce::String(snapshot.telemetry.temperatureC, 1) + " C · " +
                juce::String(snapshot.telemetry.powerWatts, 1) + " W · VRAM " +
                juce::String(snapshot.telemetry.memoryUsedMiB, 0) + "/" +
                juce::String(snapshot.telemetry.memoryTotalMiB, 0) + " MiB",
            juce::dontSendNotification);
    } else {
        telemetryLabel_.setText("Telemetry unavailable: " + juce::String(snapshot.telemetry.error),
                                juce::dontSendNotification);
    }

    backendLabel_.setText(
        juce::String(snapshot.backend.strategyName) + " · kernel " +
            juce::String(snapshot.backend.calibratedKernelMs, 2) + " ms · iterations " +
            juce::String(snapshot.backend.calibratedIterations) + " · active/idle " +
            juce::String(snapshot.lastActiveMilliseconds, 1) + "/" +
            juce::String(snapshot.lastIdleMilliseconds, 1) + " ms",
        juce::dontSendNotification);

    const auto total = snapshot.elapsedSeconds + snapshot.remainingSeconds;
    progress_ = total > 0.0 ? juce::jlimit(0.0, 1.0, snapshot.elapsedSeconds / total) : 0.0;

    if (!engine_->isRunning()) {
        startButton_.setEnabled(true);
        stopButton_.setEnabled(false);
        if (snapshot.state == EngineState::Error && !snapshot.error.empty()) {
            juce::AlertWindow::showMessageBoxAsync(
                juce::MessageBoxIconType::WarningIcon,
                "WaveMix backend error",
                juce::String(snapshot.error));
        }
    }
}

void MainComponent::startRun() {
    if (engine_ != nullptr && engine_->isRunning()) {
        return;
    }

    AppConfig config;
    config.durationSeconds = std::max(1, static_cast<int>(std::lround(
                                             durationHoursSlider_.getValue() * 3600.0)));
    config.loadPercent = loadSlider_.getValue();
    config.memoryMiB = static_cast<int>(memorySlider_.getValue());
    config.temperatureLimitC = static_cast<int>(temperatureSlider_.getValue());
    config.dryRun = dryRunToggle_.getToggleState();
    config.outputDirectory = outputDirectory();

    auto backend = createBackend(config.dryRun);
    if (backend == nullptr) {
        juce::AlertWindow::showMessageBoxAsync(
            juce::MessageBoxIconType::WarningIcon,
            "CUDA backend unavailable",
            "This build does not contain the CUDA WaveMix backend. Enable synthetic dry-run or download a release build.");
        return;
    }

    auto telemetry = config.dryRun ? makeSyntheticTelemetry() : makeNvidiaSmiTelemetry();
    engine_ = std::make_unique<StressEngine>(
        std::move(backend), std::move(telemetry), std::make_unique<RunLogger>());

    std::string error;
    if (!engine_->start(config, error)) {
        juce::AlertWindow::showMessageBoxAsync(
            juce::MessageBoxIconType::WarningIcon,
            "Cannot start WaveMix",
            juce::String(error));
        engine_.reset();
        return;
    }

    startButton_.setEnabled(false);
    stopButton_.setEnabled(true);
    progress_ = 0.0;
}

void MainComponent::stopRun() {
    if (engine_ != nullptr) {
        engine_->requestStop();
    }
}

void MainComponent::openOutputDirectory() {
    juce::File directory(juce::String(outputDirectory().string()));
    directory.createDirectory();
    directory.startAsProcess();
}

void MainComponent::configureSlider(juce::Slider& slider,
                                    double minimum,
                                    double maximum,
                                    double interval,
                                    double value,
                                    const juce::String& suffix) {
    slider.setSliderStyle(juce::Slider::LinearHorizontal);
    slider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 100, 28);
    slider.setRange(minimum, maximum, interval);
    slider.setValue(value);
    slider.setTextValueSuffix(suffix);
    slider.setColour(juce::Slider::trackColourId, juce::Colour(0xff3f8cff));
    slider.setColour(juce::Slider::backgroundColourId, juce::Colour(0xff2a3442));
    slider.setColour(juce::Slider::thumbColourId, juce::Colour(0xffdce8f8));
    slider.setColour(juce::Slider::textBoxTextColourId, juce::Colour(0xffe9eef6));
    slider.setColour(juce::Slider::textBoxBackgroundColourId, juce::Colour(0xff202631));
}

std::unique_ptr<IStressBackend> MainComponent::createBackend(bool dryRun) const {
    if (dryRun) {
        return makeSyntheticStressBackend();
    }
#if GPU_STRESS_HAS_CUDA
    return makeCudaWaveMixBackend();
#else
    return {};
#endif
}

std::filesystem::path MainComponent::outputDirectory() const {
    const auto executable = juce::File::getSpecialLocation(juce::File::currentExecutableFile);
    return std::filesystem::path(executable.getParentDirectory().getFullPathName().toStdString()) /
           "JUCE-Backup-Runs";
}

}  // namespace gpu_stress_backup
