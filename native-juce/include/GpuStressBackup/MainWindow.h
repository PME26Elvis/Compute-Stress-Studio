#pragma once

#include <juce_gui_extra/juce_gui_extra.h>

namespace gpu_stress_backup {

class MainWindow final : public juce::DocumentWindow {
public:
    MainWindow();
    void closeButtonPressed() override;

private:
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainWindow)
};

}  // namespace gpu_stress_backup
