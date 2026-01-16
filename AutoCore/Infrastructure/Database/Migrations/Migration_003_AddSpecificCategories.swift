import Foundation

/// Migration 003: Add Specific Categories
struct Migration_003_AddSpecificCategories: Migration {
    let version = 3
    let description = "Add specific_categories and specific_records tables"
    
    func up(database: DatabaseService) throws {
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS specific_categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                emoji TEXT,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            
            CREATE TABLE IF NOT EXISTS specific_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sheet_id INTEGER NOT NULL,
                row_index INTEGER NOT NULL,
                data_json TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                FOREIGN KEY (sheet_id) REFERENCES specific_categories(id) ON DELETE CASCADE
            );
        """)
    }
    
    func down(database: DatabaseService) throws {
        try database.executeSQL("DROP TABLE IF EXISTS specific_records;")
        try database.executeSQL("DROP TABLE IF EXISTS specific_categories;")
    }
}
