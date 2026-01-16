import Foundation

/// Domain Entity: Engine
struct EngineEntity {
    let id: Int64
    let brandID: Int64
    var code: EngineCode
    
    func validate() throws {
        try code.validate()
    }
}
