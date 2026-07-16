#include "GpuStressBackup/AppConfig.h"
#include "GpuStressBackup/BackgroundRunner.h"
#include "GpuStressBackup/MainWindow.h"

#include <juce_gui_extra/juce_gui_extra.h>

#include <memory>

namespace gpu_stress_backup {

class GPUStressJUCEApplication final : public juce::JUCEApplication {
public:
    const juce::String getApplicationName() override {
        return "GPU Stress JUCE Backup";
    }

    const juce::String getApplicationVersion() override {
        return "1.0.0";
    }

    bool moreThanOneInstanceAllowed() override {
        return true;
    }

    void initialise(const juce::String& commandLine) override {
        auto parsed = parseArguments(splitCommandLine(commandLine.toStdString()));
        const auto executableName =
            juce::File::getSpecialLocation(juce::File::currentExecutableFile).getFileName();
        if (executableName.containsIgnoreCase("Background")) {
            parsed.config.background = true;
        }

        if (!parsed.ok) {
            showThenQuit("Invalid command line", parsed.error);
            return;
        }
        if (parsed.config.showHelp) {
            showThenQuit("GPU Stress JUCE Backup", helpText());
            return;
        }

        if (parsed.config.background) {
            backgroundRunner_ = std::make_unique<BackgroundRunner>(parsed.config);
            std::string error;
            if (!backgroundRunner_->start(error)) {
                juce::Timer::callAfterDelay(50, [] { juce::JUCEApplicationBase::quit(); });
            }
            return;
        }

        mainWindow_ = std::make_unique<MainWindow>();
        if (parsed.config.guiSmoke) {
            juce::Timer::callAfterDelay(500, [] { juce::JUCEApplicationBase::quit(); });
        }
    }

    void shutdown() override {
        if (backgroundRunner_ != nullptr) {
            backgroundRunner_->stop();
        }
        backgroundRunner_.reset();
        mainWindow_.reset();
    }

    void systemRequestedQuit() override {
        quit();
    }

    void anotherInstanceStarted(const juce::String&) override {}

private:
    void showThenQuit(const juce::String& title, const juce::String& message) {
        juce::AlertWindow::showMessageBoxAsync(
            juce::MessageBoxIconType::InfoIcon,
            title,
            message,
            "Close",
            nullptr,
            juce::ModalCallbackFunction::create([](int) {
                juce::JUCEApplicationBase::quit();
            }));
    }

    std::unique_ptr<MainWindow> mainWindow_;
    std::unique_ptr<BackgroundRunner> backgroundRunner_;
};

}  // namespace gpu_stress_backup

START_JUCE_APPLICATION(gpu_stress_backup::GPUStressJUCEApplication)
