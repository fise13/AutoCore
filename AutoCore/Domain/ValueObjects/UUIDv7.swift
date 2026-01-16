import Foundation

/// UUID v7 Generator
/// 
/// UUID v7 - это новый стандарт UUID, который включает временную метку в первые 48 бит.
/// Это обеспечивает:
/// - Сортировку по времени создания (лексикографически)
/// - Обратную совместимость с UUID v4
/// - Лучшую производительность индексов БД
/// 
/// Реализация основана на спецификации UUID v7 (RFC draft):
/// https://datatracker.ietf.org/doc/html/draft-ietf-uuidrev-rfc4122bis
/// 
/// ПРИМЕЧАНИЕ: Текущая схема БД использует Int64 AUTOINCREMENT для ID моторов.
/// UUID v7 используется для:
/// - Correlation IDs в логах (вместо UUID v4)
/// - Будущих сущностей, которые будут использовать UUID
/// - Внешних идентификаторов
struct UUIDv7 {
    /// Генерирует UUID v7
    /// 
    /// Формат UUID v7:
    /// - 48 бит: Unix timestamp в миллисекундах
    /// - 4 бита: версия (0x7)
    /// - 2 бита: variant (0x8)
    /// - 62 бита: случайные данные
    static func generate() -> UUID {
        let timestamp = Date().timeIntervalSince1970
        let milliseconds = UInt64(timestamp * 1000)
        
        // Первые 48 бит - timestamp в миллисекундах
        let timestampBits = milliseconds & 0xFFFFFFFFFFFF
        
        // Создаем массив из 16 байтов для UUID
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        
        // Записываем timestamp в первые 6 байтов (48 бит)
        uuidBytes[0] = UInt8((timestampBits >> 40) & 0xFF)
        uuidBytes[1] = UInt8((timestampBits >> 32) & 0xFF)
        uuidBytes[2] = UInt8((timestampBits >> 24) & 0xFF)
        uuidBytes[3] = UInt8((timestampBits >> 16) & 0xFF)
        uuidBytes[4] = UInt8((timestampBits >> 8) & 0xFF)
        uuidBytes[5] = UInt8(timestampBits & 0xFF)
        
        // Генерируем случайные байты для оставшихся 10 байтов
        for i in 6..<16 {
            uuidBytes[i] = UInt8.random(in: 0...255)
        }
        
        // Устанавливаем версию 7 (биты 12-15 в байте 6)
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x70 // версия 7
        
        // Устанавливаем variant (биты 6-7 в байте 8)
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80 // variant 10
        
        // Создаем UUID из байтов
        let nsuuid = NSUUID(uuidBytes: uuidBytes)
        return nsuuid as UUID
    }
    
    /// Генерирует UUID v7 как строку
    static func generateString() -> String {
        return generate().uuidString
    }
}
