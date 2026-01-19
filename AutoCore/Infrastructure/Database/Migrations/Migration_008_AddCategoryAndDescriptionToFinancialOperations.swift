import Foundation

/// Migration 008: Add category and description fields to financial_operations
/// Добавляет поля category и description для гибкого учёта расходов
struct Migration_008_AddCategoryAndDescriptionToFinancialOperations: Migration {
    let version = 12
    let description = "Add category and description fields to financial_operations"
    
    func up(database: DatabaseService) throws {
        // Добавляем поля category и description
        try database.executeSQL("""
            ALTER TABLE financial_operations 
            ADD COLUMN category TEXT;
        """)
        
        try database.executeSQL("""
            ALTER TABLE financial_operations 
            ADD COLUMN description TEXT NOT NULL DEFAULT '';
        """)
        
        // Обновляем существующие записи: description = details, если description пустой
        try database.executeSQL("""
            UPDATE financial_operations 
            SET description = details 
            WHERE description = '' OR description IS NULL;
        """)
        
        // Индекс для быстрого поиска по категории
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_financial_operations_category 
            ON financial_operations(category);
        """)
    }
    
    func down(database: DatabaseService) throws {
        try database.executeSQL("DROP INDEX IF EXISTS idx_financial_operations_category;")
        // SQLite не поддерживает DROP COLUMN напрямую, поэтому просто оставляем поля
        // В реальном приложении можно создать новую таблицу и перекопировать данные
    }
}
