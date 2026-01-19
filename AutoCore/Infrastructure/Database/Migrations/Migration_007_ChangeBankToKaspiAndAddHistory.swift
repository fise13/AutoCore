import Foundation

/// Migration 007: Change bank to kaspi and add operation history fields
struct Migration_007_ChangeBankToKaspiAndAddHistory: Migration {
    let version = 10
    let description = "Change bank to kaspi and add operation history fields"
    
    func up(database: DatabaseService) throws {
        // Добавляем новые поля для истории операций
        try database.executeSQL("""
            ALTER TABLE financial_operations ADD COLUMN source TEXT DEFAULT '';
        """)
        
        try database.executeSQL("""
            ALTER TABLE financial_operations ADD COLUMN details TEXT DEFAULT '';
        """)
        
        // Обновляем существующие записи: bank -> kaspi
        try database.executeSQL("""
            UPDATE financial_operations SET account = 'kaspi' WHERE account = 'bank';
        """)
        
        // Пересоздаём таблицу с новым CHECK constraint
        // SQLite не поддерживает ALTER TABLE для изменения CHECK, поэтому нужно пересоздать
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS financial_operations_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL CHECK(type IN ('sale', 'refund', 'expense', 'transfer')),
                amount TEXT NOT NULL,
                payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'transfer', 'mixed')),
                cash_received TEXT,
                change_given TEXT,
                account TEXT NOT NULL CHECK(account IN ('cashbox', 'kaspi')),
                related_motor_id INTEGER,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                created_by_user TEXT NOT NULL,
                comment TEXT NOT NULL DEFAULT '',
                source TEXT NOT NULL DEFAULT '',
                details TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (related_motor_id) REFERENCES motors(id) ON DELETE SET NULL
            );
        """)
        
        // Копируем данные
        try database.executeSQL("""
            INSERT INTO financial_operations_new 
            (id, type, amount, payment_method, cash_received, change_given, account, 
             related_motor_id, created_at, created_by_user, comment, source, details)
            SELECT id, type, amount, payment_method, cash_received, change_given, 
                   CASE WHEN account = 'bank' THEN 'kaspi' ELSE account END,
                   related_motor_id, created_at, created_by_user, comment, 
                   COALESCE(source, ''), COALESCE(details, '')
            FROM financial_operations;
        """)
        
        // Удаляем старую таблицу
        try database.executeSQL("DROP TABLE financial_operations;")
        
        // Переименовываем новую таблицу
        try database.executeSQL("ALTER TABLE financial_operations_new RENAME TO financial_operations;")
        
        // Восстанавливаем индексы
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
        // Откат: kaspi -> bank
        try database.executeSQL("""
            UPDATE financial_operations SET account = 'bank' WHERE account = 'kaspi';
        """)
        
        // Удаляем новые поля (SQLite не поддерживает DROP COLUMN напрямую)
        // Нужно пересоздать таблицу без этих полей
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS financial_operations_old (
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
        
        try database.executeSQL("""
            INSERT INTO financial_operations_old 
            (id, type, amount, payment_method, cash_received, change_given, account, 
             related_motor_id, created_at, created_by_user, comment)
            SELECT id, type, amount, payment_method, cash_received, change_given, 
                   CASE WHEN account = 'kaspi' THEN 'bank' ELSE account END,
                   related_motor_id, created_at, created_by_user, comment
            FROM financial_operations;
        """)
        
        try database.executeSQL("DROP TABLE financial_operations;")
        try database.executeSQL("ALTER TABLE financial_operations_old RENAME TO financial_operations;")
        
        // Восстанавливаем индексы
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
}
