import Foundation

final class CSVExportService {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func export(database: DatabaseService, to directory: URL) throws {
        let brands = try database.fetchBrands()
        let engines = try database.fetchEngines(brandID: nil)
        let motors = try database.fetchMotors(filter: .init())

        let brandsCSV = buildBrandsCSV(brands)
        let enginesCSV = buildEnginesCSV(engines)
        let motorsCSV = buildMotorsCSV(motors)

        try write(csv: brandsCSV, to: directory.appendingPathComponent("brands.csv"))
        try write(csv: enginesCSV, to: directory.appendingPathComponent("engines.csv"))
        try write(csv: motorsCSV, to: directory.appendingPathComponent("motors.csv"))
    }

    private func buildBrandsCSV(_ brands: [Brand]) -> String {
        var rows = ["id,name"]
        for brand in brands {
            rows.append("\(brand.id),\(escape(brand.name))")
        }
        return rows.joined(separator: "\n")
    }

    private func buildEnginesCSV(_ engines: [Engine]) -> String {
        var rows = ["id,brand_id,engine_code"]
        for engine in engines {
            rows.append("\(engine.id),\(engine.brandID),\(escape(engine.code))")
        }
        return rows.joined(separator: "\n")
    }

    private func buildMotorsCSV(_ motors: [Motor]) -> String {
        var rows = ["id,engine_id,serial_code,configuration,notes,quantity,transmission,arrival_date,sold_date,created_at,updated_at,brand,engine_code"]
        for motor in motors {
            let createdAt = dateFormatter.string(from: motor.createdAt)
            let updatedAt = dateFormatter.string(from: motor.updatedAt)
            let arrival = dateFormatter.string(from: motor.arrivalDate)
            let sold = motor.soldDate.map { dateFormatter.string(from: $0) } ?? ""
            let row = [
                "\(motor.id)",
                "\(motor.engineID)",
                escape(motor.serialCode),
                escape(motor.configuration),
                escape(motor.notes),
                "\(motor.quantity)",
                escape(motor.transmission),
                arrival,
                sold,
                createdAt,
                updatedAt,
                escape(motor.brandName),
                escape(motor.engineCode)
            ].joined(separator: ",")
            rows.append(row)
        }
        return rows.joined(separator: "\n")
    }

    private func write(csv: String, to url: URL) throws {
        guard let data = csv.data(using: .utf8) else { return }
        try data.write(to: url, options: .atomic)
    }

    private func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
