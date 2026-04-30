#if os(macOS)
import AppKit

final class LoadingOverlayView: NSView {
    let blurView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.7).cgColor
        return view
    }()

    let containerView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.material = .underWindowBackground
        view.blendingMode = .withinWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.16
        view.layer?.shadowRadius = 14
        view.layer?.shadowOffset = CGSize(width: 0, height: -2)
        return view
    }()

    let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "AutoCore")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        return label
    }()

    let statusLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Checking session...")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        return label
    }()

    let progressBar: NSProgressIndicator = {
        let bar = NSProgressIndicator()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.isIndeterminate = true
        bar.style = .bar
        bar.controlSize = .small
        bar.usesThreadedAnimation = true
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 2
        bar.contentFilters = []
        if #available(macOS 10.14, *) {
            bar.appearance = NSAppearance.currentDrawing()
        }
        return bar
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func setupLayout() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(blurView)
        addSubview(containerView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(progressBar)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 340),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            progressBar.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 14),
            progressBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            progressBar.heightAnchor.constraint(equalToConstant: 3),
            progressBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -18)
        ])
    }
}

#endif
