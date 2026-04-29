import AppKit

@MainActor
final class LoadingOverlayViewController: NSViewController {
    private let overlayView = LoadingOverlayView()
    private var shownAt: Date?
    private var stillWorkingTask: DispatchWorkItem?
    private var statusSteps: [String] = ["Checking session...", "Loading data...", "Almost ready..."]
    private var statusStepIndex = 0
    private var statusAdvanceTask: DispatchWorkItem?

    override func loadView() {
        view = overlayView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        overlayView.progressBar.startAnimation(nil)
    }

    func animateIn() {
        shownAt = Date()
        startStatusTimeline()
        scheduleStillWorkingStatus()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        view.alphaValue = 0
        view.wantsLayer = true
        if !reduceMotion {
            view.layer?.transform = CATransform3DMakeScale(0.98, 0.98, 1)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().alphaValue = 1
            if !reduceMotion {
                view.layer?.animateScale(to: 1)
            }
        }
    }

    func animateOut(completion: @escaping @MainActor () -> Void) {
        stillWorkingTask?.cancel()
        stillWorkingTask = nil
        statusAdvanceTask?.cancel()
        statusAdvanceTask = nil

        let hideNow: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.view.animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor in
                    completion()
                }
            })
        }

        let minVisibleTime: TimeInterval = 0.8
        let elapsed = Date().timeIntervalSince(shownAt ?? Date())
        let remaining = max(0, minVisibleTime - elapsed)
        if remaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                hideNow()
            }
        } else {
            hideNow()
        }
    }

    func updateStatus(_ text: String) {
        overlayView.statusLabel.stringValue = text
    }

    private func startStatusTimeline() {
        statusStepIndex = 0
        updateStatus(statusSteps[statusStepIndex])
        scheduleNextStatusStep(after: 0.7)
    }

    private func scheduleNextStatusStep(after delay: TimeInterval) {
        statusAdvanceTask?.cancel()
        guard statusStepIndex < statusSteps.count - 1 else { return }

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.statusStepIndex += 1
            guard self.statusSteps.indices.contains(self.statusStepIndex) else { return }
            self.updateStatus(self.statusSteps[self.statusStepIndex])
            self.scheduleNextStatusStep(after: 0.6)
        }
        statusAdvanceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func scheduleStillWorkingStatus() {
        stillWorkingTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.updateStatus("Still working...")
        }
        stillWorkingTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }
}

@MainActor
final class LoadingOverlayManager {
    static let shared = LoadingOverlayManager()

    private weak var hostWindow: NSWindow?
    private var overlayController: LoadingOverlayViewController?

    private init() {}

    func showLoading(in window: NSWindow) {
        hostWindow = window

        guard let contentView = window.contentView else { return }
        if overlayController != nil {
            overlayController?.animateIn()
            return
        }

        let controller = LoadingOverlayViewController()
        overlayController = controller
        let overlayView = controller.view
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        controller.animateIn()
    }

    func updateStatus(text: String) {
        overlayController?.updateStatus(text)
    }

    func hideLoading() {
        guard let controller = overlayController else { return }
        controller.animateOut { [weak self, weak controller] in
            controller?.view.removeFromSuperview()
            self?.overlayController = nil
        }
    }
}

@MainActor
func showLoading(in window: NSWindow) {
    LoadingOverlayManager.shared.showLoading(in: window)
}

@MainActor
func updateStatus(text: String) {
    LoadingOverlayManager.shared.updateStatus(text: text)
}

@MainActor
func hideLoading() {
    LoadingOverlayManager.shared.hideLoading()
}

private extension CALayer {
    func animateScale(to value: CGFloat) {
        transform = CATransform3DMakeScale(value, value, 1)
    }
}
