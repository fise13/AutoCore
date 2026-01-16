import Foundation

/// Migration 004: Add Motor Indexes for Performance
/// Добавляет индексы для оптимизации запросов фильтрации моторов
struct Migration_004_AddMotorIndexes: Migration {
    let version = 4
    let description = "Add indexes for motor filtering: engine_id + sold_date composite index"
    
    func up(database: DatabaseService) throws {
        // Составной индекс для фильтрации по engine_id и sold_date одновременно
        // Это оптимизирует запросы вида: WHERE engine_id = ? AND sold_date IS NOT NULL
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_motors_engine_id_sold_date 
            ON motors(engine_id, sold_date);
        """)
        
        // Индекс для sold_date уже существует (idx_motors_sold_date)
        // Но убедимся, что он создан
        try database.executeSQL("""
            CREATE INDEX IF NOT EXISTS idx_motors_sold_date 
            ON motors(sold_date);
        """)
    }
    
    func down(database: DatabaseService) throws {
        // Удаляем только составной индекс, так как idx_motors_sold_date может использоваться отдельно
        try database.executeSQL("DROP INDEX IF EXISTS idx_motors_engine_id_sold_date;")
    }
}
