import SwiftUI
#if os(macOS)
import AppKit
#endif

struct CommandPaletteView: View {
    let sections: [(NavigationSection, String)]
    let categories: [DatabaseService.SpecificCategory]
    let motors: [Motor]
    let onSectionSelect: (NavigationSection) -> Void
    let onAdd: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let onSettings: () -> Void
    let onMotorSelect: (Int64) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedIndex = 0

    private var filteredItems: [CommandPaletteItem] {
        let all = buildItems()
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return all }
        return all.filter { item in
            switch item {
            case .section(_, let title):
                return title.lowercased().contains(q)
            case .action(let kind):
                return kind.title.lowercased().contains(q)
            case .motor(_, let serial):
                return serial.lowercased().contains(q)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Поиск разделов, действий, моторов...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { activateSelected() }
            }
            .padding(12)
            .background(Platform.controlBackgroundColor)
            .cornerRadius(8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            row(for: item, index: index)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: filteredItems.count) { _, _ in
                    selectedIndex = 0
                }
                .onChange(of: selectedIndex) { _, new in
                    let bounded = min(max(0, new), max(0, filteredItems.count - 1))
                    proxy.scrollTo(bounded, anchor: .center)
                }
            }
        }
        .frame(width: 480, height: 400)
        .padding(24)
        .background(Platform.windowBackgroundColor)
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        #if os(macOS)
        .onExitCommand { onDismiss() }
        #endif
        .background(CommandPaletteKeyMonitor(onKey: { key in
            switch key {
            case .escape: onDismiss(); return true
            case .downArrow:
                selectedIndex = min(selectedIndex + 1, max(0, filteredItems.count - 1))
                return true
            case .upArrow:
                selectedIndex = max(selectedIndex - 1, 0)
                return true
            case .return: activateSelected(); return true
            }
        }))
    }

    @ViewBuilder
    private func row(for item: CommandPaletteItem, index: Int) -> some View {
        let isSelected = index == selectedIndex
        Button {
            activate(item)
        } label: {
            HStack(spacing: 12) {
                icon(for: item)
                    .frame(width: 20, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    text(for: item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { selectedIndex = index }
        }
    }

    private func icon(for item: CommandPaletteItem) -> some View {
        Group {
            switch item {
            case .section(let section, _):
                Image(systemName: iconName(for: section))
            case .action(let kind):
                Image(systemName: kind.icon)
            case .motor:
                Image(systemName: "gearshape.2")
            }
        }
        .foregroundStyle(.secondary)
    }

    private func iconName(for section: NavigationSection) -> String {
        switch section {
        case .all: return "list.bullet"
        case .sold: return "checkmark.seal.fill"
        case .accounting: return "dollarsign.circle.fill"
        case .warehouse: return "shippingbox.fill"
        case .specificCategory: return "folder.fill"
        }
    }

    private func text(for item: CommandPaletteItem) -> Text {
        switch item {
        case .section(_, let title): return Text(title)
        case .action(let kind): return Text(kind.title)
        case .motor(_, let serial): return Text(serial)
        }
    }

    private func buildItems() -> [CommandPaletteItem] {
        var list: [CommandPaletteItem] = []
        for (section, title) in sections {
            list.append(.section(section, title))
        }
        for cat in categories {
            list.append(.section(.specificCategory(categoryID: cat.id), cat.name))
        }
        list.append(.action(.add))
        list.append(.action(.import))
        list.append(.action(.export))
        list.append(.action(.settings))
        for m in motors.prefix(50) {
            list.append(.motor(m.id, m.serialCode))
        }
        return list
    }

    private func activateSelected() {
        let items = filteredItems
        guard selectedIndex >= 0, selectedIndex < items.count else { return }
        activate(items[selectedIndex])
    }

    private func activate(_ item: CommandPaletteItem) {
        switch item {
        case .section(let section, _):
            onSectionSelect(section)
        case .action(let kind):
            switch kind {
            case .add: onAdd()
            case .import: onImport()
            case .export: onExport()
            case .settings: onSettings()
            }
        case .motor(let id, _):
            onMotorSelect(id)
        }
        onDismiss()
    }
}

enum CommandPaletteItem: Identifiable {
    case section(NavigationSection, String)
    case action(CommandPaletteAction)
    case motor(Int64, String)

    var id: String {
        switch self {
        case .section(let s, let t): return "s:\(s.id):\(t)"
        case .action(let a): return "a:\(a.id)"
        case .motor(let id, _): return "m:\(id)"
        }
    }
}

enum CommandPaletteAction {
    case add, `import`, export, settings

    var id: String {
        switch self {
        case .add: return "add"
        case .import: return "import"
        case .export: return "export"
        case .settings: return "settings"
        }
    }

    var title: String {
        switch self {
        case .add: return "Добавить мотор"
        case .import: return "Импорт Excel"
        case .export: return "Экспорт Excel"
        case .settings: return "Настройки"
        }
    }

    var icon: String {
        switch self {
        case .add: return "plus"
        case .import: return "square.and.arrow.down"
        case .export: return "square.and.arrow.up"
        case .settings: return "gearshape.fill"
        }
    }
}

private enum CommandPaletteKey {
    case escape, upArrow, downArrow, `return`
}

#if os(macOS)
private struct CommandPaletteKeyMonitor: NSViewRepresentable {
    let onKey: (CommandPaletteKey) -> Bool

    func makeNSView(context: Context) -> NSView {
        let v = CommandPaletteMonitorView()
        v.onKey = onKey
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CommandPaletteMonitorView)?.onKey = onKey
    }
}

private final class CommandPaletteMonitorView: NSView {
    var onKey: ((CommandPaletteKey) -> Bool)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let key: CommandPaletteKey? = {
                    switch event.keyCode {
                    case 53: return .escape
                    case 126: return .upArrow
                    case 125: return .downArrow
                    case 36: return .return
                    default: return nil
                    }
                }()
                if let k = key, self.onKey?(k) == true {
                    return nil
                }
                return event
            }
        } else {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }
    }
}
#else
private struct CommandPaletteKeyMonitor: View {
    init(onKey: @escaping (CommandPaletteKey) -> Bool) {}
    var body: some View { EmptyView() }
}
#endif
