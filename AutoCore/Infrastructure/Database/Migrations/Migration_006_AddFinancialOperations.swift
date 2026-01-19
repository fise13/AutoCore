import Foundation

/// Migration 006: Add Financial Operations
/// Добавляет таблицу financial_operations для учёта денег
struct Migration_006_AddFinancialOperations: Migration {
    let version = 9
    let description = "Add financial_operations table for money tracking"
    
    func up(database: DatabaseService) throws {
        // Создаем таблицу financial_operations
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS financial_operations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL CHECK(type IN ('sale', 'refund', 'expense', 'transfer')),
                amount TEXT NOT NULL,
                payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'transfer', 'mixed')),
                cash_received TEXT,
                change_given TEXT,
                account TEXT NOT NULL CHECK(account IN ('cashbox', 'bank')),
                related_motor_id INTEGER,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                created_by_user TEXT NOT NULL,
                comment TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (related_motor_id) REFERENCES motors(id) ON DELETE SET NULL
            );
        """)
        
        // Индексы для быстрого поиска
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_financial_operations_type ON financial_operations(type);
        """)
        
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_financial_operations_account ON financial_operations(account);
        """)
        
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_financial_operations_created_at ON financial_operations(created_at);
        """)
        
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_financial_operations_related_motor ON financial_operations(related_motor_id);
        """)
    }
    
    func down(database: DatabaseService) throws {
        try database.executeSQL("DROP INDEX IF EXISTS idx_financial_operations_related_motor;")
        try database.executeSQL("DROP INDEX IF EXISTS idx_financial_operations_created_at;")
        try database.executeSQL("DROP INDEX IF EXISTS idx_financial_operations_account;")
        try database.executeSQL("DROP INDEX IF EXISTS idx_financial_operations_type;")
        try database.executeSQL("DROP TABLE IF EXISTS financial_operations;")
    }
}
