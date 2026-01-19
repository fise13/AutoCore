//
//  AppDelegate.swift
//  AutoCore
//
//  Created by Виктор on 15.01.2026.
//

import Foundation
import AppKit
import FirebaseCore

/// AppDelegate для инициализации Firebase и других системных сервисов
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Firebase уже инициализирован в AutoCoreApp.init()
        // Этот метод вызывается позже, поэтому проверяем, что Firebase настроен
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured in AppDelegate.applicationDidFinishLaunching")
        } else {
            print("✅ Firebase already configured")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup при завершении приложения
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Закрывать приложение при закрытии последнего окна
        return true
    }
}
