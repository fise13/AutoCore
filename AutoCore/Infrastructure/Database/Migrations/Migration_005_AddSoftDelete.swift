import Foundation

/// Migration 005: Add Soft Delete Support
/// Добавляет поле deleted_at для мягкого удаления моторов
struct Migration_005_AddSoftDelete: Migration {
    let version = 8
    let description = "Add deleted_at field for soft delete support"
    
    func up(database: DatabaseService) throws {
        // Добавляем поле deleted_at в таблицу motors
        try database.executeSQL("""
            ALTER TABLE motors ADD COLUMN deleted_at TEXT;
        """)
        
        // Создаем индекс для быстрого поиска не удаленных моторов
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_motors_deleted_at ON motors(deleted_at);
        """)
    }
    
    func down(database: DatabaseService) throws {
        // SQLite не поддерживает DROP COLUMN напрямую
        // Для отката нужно пересоздать таблицу без deleted_at
        // Это сложная операция, поэтому просто удаляем индекс
        try database.executeSQL("DROP INDEX IF EXISTS idx_motors_deleted_at;")
    }
}
