import Foundation

/// Anti-Duplicate Service
/// Проверяет наличие дубликатов перед созданием моторов
@MainActor
final class AntiDuplicateService {
    private let motorRepository: MotorRepository
    private let logger: LoggingService
    
    init(motorRepository: MotorRepository, logger: LoggingService = .shared) {
        self.motorRepository = motorRepository
        self.logger = logger
    }
    
    /// Проверка на дубликаты
    /// Сравнение по: engine_code, serial_code, arrival_date
    func checkDuplicates(_ dto: CreateMotorDTO) throws -> [DuplicateCandidate] {
        let correlationID = UUID().uuidString
        logger.info("Checking duplicates for: \(dto.serialCode)", correlationID: correlationID)
        
        // Загружаем все моторы с похожим serial_code
        let filter = MotorFilter(searchText: dto.serialCode)
        let existingMotors = try motorRepository.findAll(filter: filter)
        
        var candidates: [DuplicateCandidate] = []
        
        for motor in existingMotors {
            let similarity = calculateSimilarity(
                existing: motor,
                candidate: dto
            )
            
            if similarity.score >= 0.7 { // Порог схожести 70%
                candidates.append(DuplicateCandidate(
                    motor: motor,
                    similarity: similarity
                ))
            }
        }
        
        if !candidates.isEmpty {
            logger.warning("Found \(candidates.count) potential duplicates", correlationID: correlationID)
        }
        
        return candidates
    }
    
    private func calculateSimilarity(
        existing: MotorEntity,
        candidate: CreateMotorDTO
    ) -> SimilarityScore {
        var score: Double = 0.0
        var factors: [String] = []
        
        // 1. Serial Code (exact match = 1.0, fuzzy = 0.5)
        if existing.serialCode.value.lowercased() == candidate.serialCode.lowercased() {
            score += 0.4
            factors.append("serial_code: exact")
        } else if existing.serialCode.value.lowercased().contains(candidate.serialCode.lowercased()) ||
                  candidate.serialCode.lowercased().contains(existing.serialCode.value.lowercased()) {
            score += 0.2
            factors.append("serial_code: fuzzy")
        }
        
        // 2. Engine ID (exact match)
        if existing.engineID == candidate.engineID {
            score += 0.3
            factors.append("engine_id: exact")
        }
        
        // 3. Arrival Date (same day = 1.0, same month = 0.5)
        let calendar = Calendar.current
        if let existingDate = calendar.dateInterval(of: .day, for: existing.arrivalDate),
           let candidateDate = calendar.dateInterval(of: .day, for: candidate.arrivalDate) {
            if existingDate == candidateDate {
                score += 0.3
                factors.append("arrival_date: same day")
            } else if calendar.isDate(existing.arrivalDate, equalTo: candidate.arrivalDate, toGranularity: .month) {
                score += 0.15
                factors.append("arrival_date: same month")
            }
        }
        
        return SimilarityScore(score: score, factors: factors)
    }
}

/// Duplicate Candidate
struct DuplicateCandidate {
    let motor: MotorEntity
    let similarity: SimilarityScore
}

/// Similarity Score
struct SimilarityScore {
    let score: Double // 0.0 - 1.0
    let factors: [String]
}
