#include "GpuStressBackup/MainWindow.h"

#include "GpuStressBackup/MainComponent.h"

namespace gpu_stress_backup {

MainWindow::MainWindow()
    : juce::DocumentWindow("GPU Stress JUCE Backup",
                           juce::Colour(0xff10141b),
                           juce::DocumentWindow::allButtons,
                           true) {
    setUsingNativeTitleBar(true);
    setResizable(true, true);
    setResizeLimits(700, 560, 1200, 900);
    setContentOwned(new MainComponent(), true);
    centreWithSize(getWidth(), getHeight());
    setVisible(true);
}

void MainWindow::closeButtonPressed() {
    juce::JUCEApplication::getInstance()->systemRequestedQuit();
}

}  // namespace gpu_stress_backup
