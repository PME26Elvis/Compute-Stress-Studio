#pragma once

#include <juce_gui_extra/juce_gui_extra.h>

#include <memory>

namespace gpu_stress_backup {

class MainComponent;

class MainWindow final : public juce::DocumentWindow {
public:
    MainWindow();
    ~MainWindow() override;

    void closeButtonPressed() override;
    void minimisationStateChanged(bool isNowMinimised) override;

    void showFromTray();
    void hideToTray();
    void stopStress();
    [[nodiscard]] bool isStressRunning() const noexcept;
    [[nodiscard]] bool hasTrayIcon() const noexcept;

private:
    class TrayIcon;
    void requestExit();

    MainComponent* mainComponent_ = nullptr;
    std::unique_ptr<TrayIcon> trayIcon_;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainWindow)
};

}  // namespace gpu_stress_backup
