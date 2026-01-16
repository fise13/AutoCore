import Foundation
import AppKit
import OSLog
import Combine

/// Update Service
/// Проверяет наличие обновлений через latest.json
@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    /// URL источника обновлений (СТРОГО единственный источник)
    private let updateURL = URL(string: "https://fise13.github.io/AutoCreators/updates/latest.json")!
    
    /// Интервал проверки обновлений (в часах)
    private let checkIntervalHours: TimeInterval = 24
    
    private let logger: LoggingService
    private var checkTimer: Timer?
    private var lastCheckDate: Date?
    
    @Published var availableUpdate: UpdateInfo?
    @Published var isCheckingForUpdates = false
    @Published var isDownloadingUpdate = false
    @Published var downloadProgress: Double = 0.0
    @Published var showSuccessDialog = false
    @Published var successVersion: String?
    
    private init(logger: LoggingService = .shared) {
        self.logger = logger
        restoreLastCheckDate()
    }
    
    /// Запуск сервиса обновлений
    /// Вызывается при запуске приложения
    func start() {
        logger.info("UpdateService: Starting update service")
        
        // Проверка при запуске
        Task {
            await checkForUpdates()
        }
        
        // Настройка периодической проверки
        schedulePeriodicCheck()
    }
    
    /// Остановка сервиса обновлений
    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    // MARK: - Проверка обновлений
    
    /// Проверка наличия обновлений
    func checkForUpdates() async {
        // Проверяем, не слишком ли часто проверяем
        if let lastCheck = lastCheckDate,
           Date().timeIntervalSince(lastCheck) < checkIntervalHours * 3600 {
            logger.info("UpdateService: Skipping check, last check was too recent")
            return
        }
        
        await MainActor.run {
            isCheckingForUpdates = true
        }
        
        logger.info("UpdateService: Checking for updates from \(updateURL.absoluteString)")
        
        do {
            // GET запрос к latest.json
            let (data, response) = try await URLSession.shared.data(from: updateURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UpdateError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw UpdateError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Парсинг JSON
            let updateInfo = try parseUpdateInfo(from: data)
            
            logger.info("UpdateService: Successfully loaded latest.json - version: \(updateInfo.version), build: \(updateInfo.build)")
            
            // Сравнение build с CFBundleVersion
            let currentBuild = getCurrentBuildNumber()
            
            logger.info("UpdateService: Current build: \(currentBuild), latest build: \(updateInfo.build)")
            
            if updateInfo.build > currentBuild {
                // Обновление доступно
                await MainActor.run {
                    self.availableUpdate = updateInfo
                    self.lastCheckDate = Date()
                    self.saveLastCheckDate()
                }
                logger.info("UpdateService: Update available - version \(updateInfo.version), build \(updateInfo.build)")
            } else {
                // Обновлений нет
                await MainActor.run {
                    self.availableUpdate = nil
                    self.lastCheckDate = Date()
                    self.saveLastCheckDate()
                }
                logger.info("UpdateService: No updates available (current build: \(currentBuild), latest build: \(updateInfo.build))")
            }
            
        } catch {
            // Ошибки НЕ показываем пользователю, только логируем
            logger.warning("UpdateService: Failed to check for updates - \(error.localizedDescription)")
            
            // В случае ошибки приложение продолжает работать
        }
        
        await MainActor.run {
            isCheckingForUpdates = false
        }
    }
    
    // MARK: - Парсинг JSON
    
    private func parseUpdateInfo(from data: Data) throws -> UpdateInfo {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UpdateError.invalidJSON
        }
        
        // Строгая проверка структуры JSON
        guard let app = json["app"] as? String,
              let version = json["version"] as? String,
              let build = json["build"] as? Int,
              let notes = json["notes"] as? [String],
              let urlString = json["url"] as? String,
              let url = URL(string: urlString) else {
            throw UpdateError.invalidJSONStructure
        }
        
        let minSchemaVersion = json["minSchemaVersion"] as? Int ?? 0
        let mandatory = json["mandatory"] as? Bool ?? false
        
        return UpdateInfo(
            app: app,
            version: version,
            build: build,
            notes: notes,
            url: url,
            minSchemaVersion: minSchemaVersion,
            mandatory: mandatory
        )
    }
    
    // MARK: - Установка обновления
    
    /// Скачивание и установка обновления
    func downloadAndInstallUpdate() async throws {
        guard let updateInfo = availableUpdate else {
            throw UpdateError.noUpdateAvailable
        }
        
        await MainActor.run {
            isDownloadingUpdate = true
            downloadProgress = 0.0
        }
        
        logger.info("UpdateService: Starting download from \(updateInfo.url.absoluteString)")
        
        // 1. Скачать ZIP
        let zipURL = try await downloadZIP(from: updateInfo.url)
        
        logger.info("UpdateService: ZIP downloaded to \(zipURL.path)")
        
        // 2. Распаковать во временную директорию
        let extractedURL = try await extractZIP(at: zipURL)
        
        logger.info("UpdateService: ZIP extracted to \(extractedURL.path)")
        
        // 3. Проверить наличие AutoCreators.app в распакованной директории
        // Может быть в корне или в поддиректории
        var appURL = extractedURL.appendingPathComponent("AutoCreators.app")
        
        if !FileManager.default.fileExists(atPath: appURL.path) {
            // Проверяем содержимое директории
            let contents = try? FileManager.default.contentsOfDirectory(at: extractedURL, includingPropertiesForKeys: nil)
            if let appBundle = contents?.first(where: { $0.lastPathComponent.hasSuffix(".app") && $0.lastPathComponent.contains("AutoCreators") }) {
                appURL = appBundle
            } else {
                throw UpdateError.appNotFound
            }
        }
        
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw UpdateError.appNotFound
        }
        
        logger.info("UpdateService: AutoCreators.app found at \(appURL.path)")
        
        // 4. Заменить текущий .app
        try await replaceCurrentApp(with: appURL)
        
        logger.info("UpdateService: Current app replaced successfully")
        
        // 5. Показать диалог об успешном обновлении
        await MainActor.run {
            isDownloadingUpdate = false
            downloadProgress = 1.0
            successVersion = updateInfo.version
            showSuccessDialog = true
        }
        
        // Завершение приложения произойдет после закрытия диалога в RootView
        // 6. Запустить новую версию и завершить текущую будет вызвано из RootView
    }
    
    private func downloadZIP(from url: URL) async throws -> URL {
        // Создаем временный файл
        let tempDir = FileManager.default.temporaryDirectory
        let zipURL = tempDir.appendingPathComponent("AutoCreators-update-\(UUID().uuidString).zip")
        
        // Удаляем старый файл, если есть
        try? FileManager.default.removeItem(at: zipURL)
        
        // Используем URLSession для скачивания с прогрессом
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.downloadFailed
        }
        
        // Сохраняем данные в файл
        try data.write(to: zipURL)
        
        // Обновляем прогресс
        await MainActor.run {
            self.downloadProgress = 0.9 // 90% на скачивание
        }
        
        return zipURL
    }
    
    private func extractZIP(at zipURL: URL) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let extractedDir = tempDir.appendingPathComponent("AutoCreators-update-\(UUID().uuidString)")
        
        // Удаляем старую директорию, если есть
        try? FileManager.default.removeItem(at: extractedDir)
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        
        // Используем Process для распаковки ZIP
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", zipURL.path, "-d", extractedDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw UpdateError.extractionFailed
        }
        
        logger.info("UpdateService: Extraction completed")
        
        // Обновляем прогресс
        await MainActor.run {
            self.downloadProgress = 0.95 // 95% на распаковку
        }
        
        return extractedDir
    }
    
    private func replaceCurrentApp(with newAppURL: URL) async throws {
        let currentAppURL = Bundle.main.bundleURL
        
        // Получаем путь к директории с .app
        let appContainerURL = currentAppURL.deletingLastPathComponent()
        
        // Определяем имя целевого приложения
        // Если текущее приложение AutoCore.app, а обновление для AutoCreators.app
        // Определяем по Bundle.main.infoDictionary или используем имя из newAppURL
        let currentAppName = currentAppURL.lastPathComponent
        let newAppName = newAppURL.lastPathComponent
        
        // Если новое приложение называется по-другому, используем его имя
        let targetAppName = (newAppName != "AutoCore.app") ? newAppName : "AutoCreators.app"
        let targetURL = appContainerURL.appendingPathComponent(targetAppName)
        
        // Удаляем старую версию (переименовываем для безопасности)
        let backupURL = appContainerURL.appendingPathComponent("\(targetAppName.replacingOccurrences(of: ".app", with: ""))-backup.app")
        try? FileManager.default.removeItem(at: backupURL)
        
        // Если текущее приложение называется по-другому, не трогаем его
        // Создаем новое приложение рядом
        if currentAppName != targetAppName {
            // Просто копируем новое приложение
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.copyItem(at: newAppURL, to: targetURL)
            logger.info("UpdateService: New app copied to \(targetURL.path)")
        } else {
            // Заменяем текущее приложение
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.moveItem(at: targetURL, to: backupURL)
                logger.info("UpdateService: Old app moved to backup")
            }
            
            // Копируем новую версию
            try FileManager.default.copyItem(at: newAppURL, to: targetURL)
            logger.info("UpdateService: New app copied to \(targetURL.path)")
            
            // Удаляем backup после успешного копирования
            try? FileManager.default.removeItem(at: backupURL)
        }
        
        // Обновляем прогресс
        await MainActor.run {
            self.downloadProgress = 0.98 // 98% на замену
        }
    }
    
    private func launchNewVersion() throws {
        let currentAppURL = Bundle.main.bundleURL
        
        let appContainerURL = currentAppURL.deletingLastPathComponent()
        
        // Определяем путь к новому приложению
        // Проверяем, существует ли AutoCreators.app
        var newAppURL = appContainerURL.appendingPathComponent("AutoCreators.app")
        
        if !FileManager.default.fileExists(atPath: newAppURL.path) {
            // Если нет AutoCreators.app, ищем любой .app с AutoCreators в имени
            let contents = try? FileManager.default.contentsOfDirectory(at: appContainerURL, includingPropertiesForKeys: nil)
            if let appBundle = contents?.first(where: { $0.lastPathComponent.hasSuffix(".app") && $0.lastPathComponent.contains("AutoCreators") }) {
                newAppURL = appBundle
            } else {
                // Если не нашли, используем текущий путь (для случая, когда имя не менялось)
                newAppURL = currentAppURL
            }
        }
        
        guard FileManager.default.fileExists(atPath: newAppURL.path) else {
            throw UpdateError.appNotFound
        }
        
        logger.info("UpdateService: Launching new version from \(newAppURL.path)")
        
        // Запускаем новую версию
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        NSWorkspace.shared.openApplication(
            at: newAppURL,
            configuration: configuration
        ) { app, error in
            if let error = error {
                self.logger.error("UpdateService: Failed to launch new version", error: error)
            } else {
                self.logger.info("UpdateService: New version launched successfully")
            }
        }
        
        // Завершаем текущую версию с небольшой задержкой
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // MARK: - Вспомогательные методы
    
    private func getCurrentBuildNumber() -> Int {
        guard let buildString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let build = Int(buildString) else {
            logger.warning("UpdateService: Cannot read CFBundleVersion, defaulting to 0")
            return 0
        }
        return build
    }
    
    private func schedulePeriodicCheck() {
        // Останавливаем старый таймер
        checkTimer?.invalidate()
        
        // Создаем новый таймер с интервалом checkIntervalHours
        let interval = checkIntervalHours * 3600
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForUpdates()
            }
        }
    }
    
    // MARK: - Сохранение состояния
    
    private func saveLastCheckDate() {
        UserDefaults.standard.set(lastCheckDate, forKey: "UpdateService.lastCheckDate")
    }
    
    private func restoreLastCheckDate() {
        lastCheckDate = UserDefaults.standard.object(forKey: "UpdateService.lastCheckDate") as? Date
    }
}

// MARK: - UpdateInfo

struct UpdateInfo: Codable {
    let app: String
    let version: String
    let build: Int
    let notes: [String]
    let url: URL
    let minSchemaVersion: Int
    let mandatory: Bool
}

// MARK: - UpdateError

enum UpdateError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case invalidJSON
    case invalidJSONStructure
    case noUpdateAvailable
    case downloadFailed
    case extractionFailed
    case appNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .invalidJSON:
            return "Invalid JSON format"
        case .invalidJSONStructure:
            return "JSON structure does not match expected format"
        case .noUpdateAvailable:
            return "No update available"
        case .downloadFailed:
            return "Failed to download update"
        case .extractionFailed:
            return "Failed to extract ZIP archive"
        case .appNotFound:
            return "Application bundle not found"
        }
    }
}
