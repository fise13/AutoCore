//
//  AutoCoreAccountingApp.swift
//  AutoCoreAccounting
//
//  Created by Виктор on 05.03.2026.
//

import SwiftUI
import CoreData

@main
struct AutoCoreAccountingApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
