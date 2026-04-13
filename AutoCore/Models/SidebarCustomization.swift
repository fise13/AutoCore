#if os(macOS)

import Foundation

enum SidebarBaseSection: String, CaseIterable, Codable, Identifiable {
    case all
    case sold
    case accounting
    case warehouse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.Navigation.allMotors
        case .sold: return L10n.Navigation.sold
        case .accounting: return L10n.Navigation.accounting
        case .warehouse: return L10n.Navigation.warehouse
        }
    }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .sold: return "checkmark.seal.fill"
        case .accounting: return "dollarsign.circle.fill"
        case .warehouse: return "shippingbox.fill"
        }
    }
}

struct SidebarCustomization: Codable {
    var orderedSections: [SidebarBaseSection]
    var hiddenSections: Set<SidebarBaseSection>
    var showSpecificCategories: Bool
    var showBrandsBlock: Bool

    static let `default` = SidebarCustomization(
        orderedSections: [.all, .sold, .accounting, .warehouse],
        hiddenSections: [],
        showSpecificCategories: true,
        showBrandsBlock: true
    )

    func isVisible(_ section: SidebarBaseSection) -> Bool {
        !hiddenSections.contains(section)
    }
}

#endif
