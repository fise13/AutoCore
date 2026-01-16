import Foundation

/// Migration 001: Initial Schema
struct Migration_001_Init: Migration {
    let version = 1
    let description = "Initial database schema"
    
    func up(database: DatabaseService) throws {
        // Brands
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS brands (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
        """)
        
        // Engines
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS engines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                brand_id INTEGER NOT NULL,
                engine_code TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                UNIQUE(brand_id, engine_code),
                FOREIGN KEY (brand_id) REFERENCES brands(id) ON DELETE CASCADE
            );
        """)
        
        // Motors
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS motors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                engine_id INTEGER NOT NULL,
                serial_code TEXT NOT NULL UNIQUE,
                configuration TEXT NOT NULL DEFAULT '',
                notes TEXT NOT NULL DEFAULT '',
                quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity >= 1),
                transmission TEXT NOT NULL DEFAULT '',
                arrival_date TEXT NOT NULL,
                sold_date TEXT,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now')),
                FOREIGN KEY (engine_id) REFERENCES engines(id) ON DELETE CASCADE
            );
        """)
    }
    
    func down(database: DatabaseService) throws {
        try database.executeSQL("DROP TABLE IF EXISTS motors;")
        try database.executeSQL("DROP TABLE IF EXISTS engines;")
        try database.executeSQL("DROP TABLE IF EXISTS brands;")
    }
}
