import Foundation

/// Migration 002: Add Audit Log
struct Migration_002_AddAuditLog: Migration {
    let version = 2
    let description = "Add audit_log table for domain events"
    
    func up(database: DatabaseService) throws {
        try database.executeSQL("""
            CREATE TABLE IF NOT EXISTS audit_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_type TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id INTEGER NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            
            CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON audit_log(entity_type, entity_id);
            CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at);
        """)
    }
    
    func down(database: DatabaseService) throws {
        try database.executeSQL("DROP TABLE IF EXISTS audit_log;")
    }
}
