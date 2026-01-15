//
//  AutoCoreApp.swift
//  AutoCore
//
//  Created by Виктор on 15.01.2026.
//

import SwiftUI
import CoreData

@main
struct AutoCoreApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
