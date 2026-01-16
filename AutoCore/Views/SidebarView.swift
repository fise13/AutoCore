import SwiftUI

struct SidebarView: View {
    let brands: [Brand]
    let engines: [Engine]
    @Binding var selectedSection: NavigationSection
    @Binding var selectedBrandID: Int64?
    @Binding var selectedEngineID: Int64?

    @State private var expandedBrands: Set<Int64> = []

    var body: some View {
        List(selection: $selectedSection) {
            Section {
                ForEach([NavigationSection.all, .sold]) { section in
                    Label(section.title, systemImage: section == .sold ? "checkmark.seal.fill" : "list.bullet")
                        .tag(section)
                }
            }
            
            Section("Специфичные") {
                ForEach(NavigationSection.specificSections) { section in
                    HStack(spacing: 6) {
                        Text(section.emoji)
                        Text(section.title)
                    }
                    .tag(section)
                }
            }
            
            if selectedSection == .all {
                Section("Бренды") {
                    Button("Все бренды") {
                        selectedBrandID = nil
                        selectedEngineID = nil
                    }
                    .buttonStyle(.plain)

                    ForEach(brands) { brand in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedBrands.contains(brand.id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedBrands.insert(brand.id)
                                    } else {
                                        expandedBrands.remove(brand.id)
                                    }
                                }
                            )
                        ) {
                            ForEach(engines.filter { $0.brandID == brand.id }) { engine in
                                Button(engine.code.uppercased()) {
                                    selectedBrandID = brand.id
                                    selectedEngineID = engine.id
                                }
                                .buttonStyle(.plain)
                            }
                        } label: {
                            Button(brand.name) {
                                selectedBrandID = brand.id
                                selectedEngineID = nil
                                expandedBrands.insert(brand.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}
