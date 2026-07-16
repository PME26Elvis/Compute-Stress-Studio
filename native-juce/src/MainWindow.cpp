#include "GpuStressBackup/MainWindow.h"

#include "GpuStressBackup/MainComponent.h"

namespace gpu_stress_backup {

class MainWindow::TrayIcon final : public juce::SystemTrayIconComponent {
public:
    explicit TrayIcon(MainWindow& owner) : owner_(owner) {
        juce::Image icon(juce::Image::ARGB, 32, 32, true);
        juce::Graphics graphics(icon);
        graphics.setColour(juce::Colour(0xff2166d1));
        graphics.fillRoundedRectangle(icon.getBounds().toFloat().reduced(2.0f), 7.0f);
        graphics.setColour(juce::Colours::white);
        graphics.setFont(juce::Font(juce::FontOptions(20.0f, juce::Font::bold)));
        graphics.drawText("G", icon.getBounds(), juce::Justification::centred, false);
        setIconImage(icon, icon);
        setIconTooltip("GPU Stress JUCE Backup");
    }

    void mouseDoubleClick(const juce::MouseEvent&) override {
        owner_.showFromTray();
    }

    void mouseDown(const juce::MouseEvent& event) override {
        if (event.mods.isPopupMenu()) {
            showMenu();
        } else if (event.mods.isLeftButtonDown()) {
            owner_.showFromTray();
        }
    }

private:
    void showMenu() {
        juce::PopupMenu menu;
        menu.addItem(1, "Show window", true, owner_.isVisible());
        menu.addItem(2, "Hide to background", true, !owner_.isVisible());
        menu.addSeparator();
        menu.addItem(3, "Stop stress", owner_.isStressRunning());
        menu.addItem(4, "Exit");

        juce::Component::SafePointer<MainWindow> safeOwner(&owner_);
        menu.showMenuAsync(juce::PopupMenu::Options(), [safeOwner](int result) {
            if (safeOwner == nullptr) {
                return;
            }
            switch (result) {
                case 1: safeOwner->showFromTray(); break;
                case 2: safeOwner->hideToTray(); break;
                case 3: safeOwner->stopStress(); break;
                case 4: safeOwner->requestExit(); break;
                default: break;
            }
        });
    }

    MainWindow& owner_;
};

MainWindow::MainWindow()
    : juce::DocumentWindow("GPU Stress JUCE Backup",
                           juce::Colour(0xff10141b),
                           juce::DocumentWindow::allButtons,
                           true) {
    setUsingNativeTitleBar(true);
    setResizable(true, true);
    setResizeLimits(700, 460, 1200, 800);

    auto content = std::make_unique<MainComponent>([this] { hideToTray(); });
    mainComponent_ = content.get();
    setContentOwned(content.release(), true);

    trayIcon_ = std::make_unique<TrayIcon>(*this);
    centreWithSize(getWidth(), getHeight());
    setVisible(true);
}

MainWindow::~MainWindow() {
    stopStress();
    trayIcon_.reset();
}

void MainWindow::closeButtonPressed() {
    hideToTray();
}

void MainWindow::minimisationStateChanged(bool isNowMinimised) {
    if (isNowMinimised) {
        juce::Component::SafePointer<MainWindow> safeThis(this);
        juce::MessageManager::callAsync([safeThis] {
            if (safeThis != nullptr) {
                safeThis->hideToTray();
            }
        });
    }
}

void MainWindow::showFromTray() {
    setMinimised(false);
    setVisible(true);
    toFront(true);
}

void MainWindow::hideToTray() {
    setMinimised(false);
    setVisible(false);
}

void MainWindow::stopStress() {
    if (mainComponent_ != nullptr) {
        mainComponent_->stopRun();
    }
}

bool MainWindow::isStressRunning() const noexcept {
    return mainComponent_ != nullptr && mainComponent_->isStressRunning();
}

bool MainWindow::hasTrayIcon() const noexcept {
    return trayIcon_ != nullptr;
}

void MainWindow::requestExit() {
    stopStress();
    if (auto* app = juce::JUCEApplication::getInstance()) {
        app->systemRequestedQuit();
    }
}

}  // namespace gpu_stress_backup
