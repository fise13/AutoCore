import Foundation
import OSLog

/// Centralized Logging Service
/// Thread-safe logging service that can be used from any actor context
nonisolated final class LoggingService {
    nonisolated(unsafe) static let shared = LoggingService()
    
    private let logger = Logger(subsystem: "com.autocore", category: "App")
    private let fileLogger: FileLogger?
    
    private init() {
        // Инициализация файлового логгера
        if let logURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("AutoCore/logs/app.log") {
            self.fileLogger = FileLogger(logURL: logURL)
        } else {
            self.fileLogger = nil
        }
    }
    
    func info(_ message: String, correlationID: String? = nil) {
        let prefix = correlationID.map { "[\($0)] " } ?? ""
        logger.info("\(prefix)\(message)")
        fileLogger?.log(level: .info, message: "\(prefix)\(message)")
    }
    
    func warning(_ message: String, correlationID: String? = nil) {
        let prefix = correlationID.map { "[\($0)] " } ?? ""
        logger.warning("\(prefix)\(message)")
        fileLogger?.log(level: .warning, message: "\(prefix)\(message)")
    }
    
    func error(_ message: String, error: Error? = nil, correlationID: String? = nil) {
        let prefix = correlationID.map { "[\($0)] " } ?? ""
        let errorMsg = error.map { " - \($0.localizedDescription)" } ?? ""
        logger.error("\(prefix)\(message)\(errorMsg)")
        fileLogger?.log(level: .error, message: "\(prefix)\(message)\(errorMsg)")
    }
}

/// File-based logger
private final class FileLogger {
    private let logURL: URL
    private let queue = DispatchQueue(label: "com.autocore.logging")
    
    init(logURL: URL) {
        self.logURL = logURL
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
    
    func log(level: LogLevel, message: String) {
        queue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let logEntry = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
            
            if let data = logEntry.data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: self.logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    // Если файл не существует, создаем его и записываем данные
                    if FileManager.default.fileExists(atPath: self.logURL.path) {
                        // Файл существует, но не можем открыть FileHandle - используем append через Data
                        if let existingData = try? Data(contentsOf: self.logURL) {
                            var combinedData = existingData
                            combinedData.append(data)
                            try? combinedData.write(to: self.logURL, options: .atomic)
                        } else {
                            try? data.write(to: self.logURL, options: .atomic)
                        }
                    } else {
                        // Файл не существует, создаем новый
                        try? data.write(to: self.logURL, options: .atomic)
                    }
                }
            }
        }
    }
    
    enum LogLevel: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}
