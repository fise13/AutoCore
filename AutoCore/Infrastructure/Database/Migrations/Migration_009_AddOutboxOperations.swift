import Foundation

/// Migration 009: Add outbox_operations table for Supabase sync
/// Таблица для хранения операций, ожидающих синхронизации с Supabase
struct Migration_009_AddOutboxOperations: Migration {
    let version = 14
    let description = "Add outbox_operations table for Supabase sync"
    
    func up(database: DatabaseService) throws {
        // Создаём таблицу outbox_operations
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS outbox_operations (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL,
                operation_type TEXT NOT NULL CHECK(operation_type IN ('sale', 'expense', 'refund', 'transfer')),
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'sent', 'failed')),
                retry_count INTEGER NOT NULL DEFAULT 0,
                last_error TEXT,
                synced_at TEXT
            );
        """)
        
        // Индексы для быстрого поиска
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_outbox_operations_status 
            ON outbox_operations(status);
        """)
        
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_outbox_operations_created_at 
            ON outbox_operations(created_at);
        """)
    }
    
    func down(database: DatabaseService) throws {
        try database.executeSQL("DROP INDEX IF EXISTS idx_outbox_operations_created_at;")
        try database.executeSQL("DROP INDEX IF EXISTS idx_outbox_operations_status;")
        try database.executeSQL("DROP TABLE IF EXISTS outbox_operations;")
    }
}
