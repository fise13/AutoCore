# Архитектура AutoCore

## Обзор

AutoCore использует **Clean Architecture** с четким разделением на слои:

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│  (Views, ViewModels - UI only)      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Application Layer              │
│  (Use Cases, DTOs, Event Bus)      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Domain Layer                   │
│  (Entities, Value Objects, Rules)  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Infrastructure Layer            │
│  (Database, Excel, Logging, File)  │
└─────────────────────────────────────┘
```

## Структура проекта

```
AutoCore/
├── Domain/                          # Domain Layer
│   ├── Entities/                    # Domain Entities
│   │   ├── MotorEntity.swift
│   │   ├── BrandEntity.swift
│   │   └── EngineEntity.swift
│   ├── ValueObjects/                # Value Objects
│   │   ├── SerialCode.swift
│   │   ├── EngineCode.swift
│   │   └── Quantity.swift
│   ├── Events/                      # Domain Events
│   │   └── DomainEvent.swift
│   └── Errors/                      # Domain Errors
│       └── DomainError.swift
│
├── Application/                     # Application Layer
│   ├── UseCases/                    # Use Cases
│   │   ├── CreateMotorUseCase.swift
│   │   ├── UpdateMotorUseCase.swift
│   │   └── SellMotorUseCase.swift
│   ├── Repositories/                # Repository Interfaces
│   │   └── MotorRepository.swift
│   ├── Services/                    # Application Services
│   │   └── AntiDuplicateService.swift
│   ├── EventBus/                    # Event Bus
│   │   └── EventBus.swift
│   └── Errors/                      # Application Errors
│       └── AppError.swift
│
├── Infrastructure/                  # Infrastructure Layer
│   ├── Database/                    # Database Implementation
│   │   ├── Repositories/
│   │   │   └── MotorRepositoryImpl.swift
│   │   ├── Migrations/
│   │   │   ├── Migration.swift
│   │   │   ├── Migration_001_Init.swift
│   │   │   ├── Migration_002_AddAuditLog.swift
│   │   │   └── Migration_003_AddSpecificCategories.swift
│   │   └── DatabaseServiceExtensions.swift
│   ├── Logging/                     # Logging Service
│   │   └── LoggingService.swift
│   └── Audit/                       # Audit Log Service
│       └── AuditLogService.swift
│
├── Presentation/                    # Presentation Layer
│   ├── Views/                       # SwiftUI Views
│   └── ViewModels/                  # ViewModels (UI only)
│
├── Models/                          # Legacy Models (deprecated)
└── Services/                        # Legacy Services (deprecated)
```

## Слои архитектуры

### 1. Domain Layer (Домен)

**Ответственность:**
- Бизнес-логика и правила
- Валидация данных
- Domain Events

**Запрещено:**
- Зависимости от других слоев
- UI-логика
- Работа с БД напрямую

**Компоненты:**

#### Entities
- `MotorEntity` - мотор с бизнес-логикой
- `BrandEntity` - бренд
- `EngineEntity` - двигатель

#### Value Objects
- `SerialCode` - серийный номер (валидация)
- `EngineCode` - код двигателя (валидация)
- `Quantity` - количество (>= 1)

#### Domain Rules
- Мотор не может быть продан дважды
- `sold_date != null` → статус продан
- `quantity >= 1`
- `serial_code` обязателен

#### Domain Events
- `MotorCreatedEvent`
- `MotorUpdatedEvent`
- `MotorSoldEvent`
- `MotorUnsoldEvent`
- `MotorImportedEvent`
- `MotorDeletedEvent`

### 2. Application Layer (Приложение)

**Ответственность:**
- Use Cases (бизнес-сценарии)
- Координация Domain и Infrastructure
- DTOs для передачи данных

**Запрещено:**
- UI-логика
- Прямая работа с БД

**Компоненты:**

#### Use Cases
- `CreateMotorUseCase` - создание мотора
- `UpdateMotorUseCase` - обновление мотора
- `SellMotorUseCase` - продажа мотора
- `ImportExcelUseCase` - импорт из Excel
- `ExportExcelUseCase` - экспорт в Excel

#### Event Bus
- `EventBus` - in-memory шина событий
- Публикация Domain Events
- Подписка на события

#### Application Services
- `AntiDuplicateService` - проверка дубликатов

### 3. Infrastructure Layer (Инфраструктура)

**Ответственность:**
- Реализация Repository
- Работа с БД (SQLite)
- Работа с файлами (Excel)
- Логирование
- Audit Log

**Компоненты:**

#### Database
- `MotorRepositoryImpl` - реализация репозитория
- `DatabaseService` - работа с SQLite
- `MigrationManager` - управление миграциями

#### Migrations
- `Migration_001_Init` - начальная схема
- `Migration_002_AddAuditLog` - таблица audit_log
- `Migration_003_AddSpecificCategories` - специфичные категории

#### Logging
- `LoggingService` - централизованное логирование
- Запись в файл и консоль
- Структурированные логи с correlation_id

#### Audit
- `AuditLogService` - автоматическое логирование событий
- Подписка на EventBus
- Запись в `audit_log` таблицу

### 4. Presentation Layer (Представление)

**Ответственность:**
- UI (SwiftUI Views)
- Связь UI ↔ Application Layer
- Обработка пользовательского ввода

**Запрещено:**
- Бизнес-логика
- Валидация (только UI-валидация)
- Прямой доступ к БД

**Компоненты:**

#### ViewModels
- Только UI-логика
- Вызов Use Cases
- Преобразование Domain → UI Models

#### Views
- SwiftUI компоненты
- Обработка событий UI
- Отображение данных

## Поток данных

### Создание мотора

```
User Input (View)
    ↓
ViewModel.createMotor()
    ↓
CreateMotorUseCase.execute(dto)
    ↓
MotorRepository.save(entity)
    ↓
DatabaseService.insertOrUpdateMotor()
    ↓
EventBus.publish(MotorCreatedEvent)
    ↓
AuditLogService.logEvent()
    ↓
ViewModel.updateUI()
```

### Продажа мотора

```
User Action (View)
    ↓
ViewModel.sellMotor()
    ↓
SellMotorUseCase.execute(motorID)
    ↓
MotorRepository.findByID()
    ↓
MotorEntity.sell(date)  // Domain Rule
    ↓
MotorRepository.save()
    ↓
EventBus.publish(MotorSoldEvent)
    ↓
AuditLogService.logEvent()
```

## Domain Rules

### MotorEntity

1. **Мотор не может быть продан дважды**
   ```swift
   mutating func sell(on date: Date) throws {
       guard !isSold else {
           throw DomainError.logicError(message: "Мотор уже продан")
       }
       // ...
   }
   ```

2. **Дата продажи >= даты прихода**
   ```swift
   guard date >= arrivalDate else {
       throw DomainError.validationError(message: "Дата продажи не может быть раньше даты прихода")
   }
   ```

3. **serial_code обязателен**
   ```swift
   func validate() throws {
       guard !serialCode.value.isEmpty else {
           throw DomainError.validationError(message: "Серийный номер обязателен")
       }
   }
   ```

4. **quantity >= 1**
   ```swift
   struct Quantity {
       init(_ value: Int) throws {
           guard value >= 1 else {
               throw DomainError.validationError(message: "Количество должно быть >= 1")
           }
       }
   }
   ```

## Event-Driven Architecture

### Event Bus

```swift
// Публикация события
EventBus.shared.publish(MotorCreatedEvent(...))

// Подписка на события
let id = EventBus.shared.subscribe(to: MotorCreatedEvent.self) { event in
    // Обработка события
}
```

### Audit Log

Все Domain Events автоматически логируются в `audit_log`:

```sql
CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id INTEGER NOT NULL,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

## Миграции БД

### Система версионирования

```swift
// Текущая версия схемы
let CURRENT_SCHEMA_VERSION = 3

// Миграции
let migrations: [Migration] = [
    Migration_001_Init(),
    Migration_002_AddAuditLog(),
    Migration_003_AddSpecificCategories()
]

// Применение миграций
let manager = MigrationManager(database: database, migrations: migrations)
try manager.migrate()
```

### Создание новой миграции

```swift
struct Migration_004_NewFeature: Migration {
    let version = 4
    let description = "Add new feature"
    
    func up(database: DatabaseService) throws {
        try database.execute(sql: """
            CREATE TABLE IF NOT EXISTS new_table (...);
        """)
    }
    
    func down(database: DatabaseService) throws {
        try database.execute(sql: "DROP TABLE IF EXISTS new_table;")
    }
}
```

## Error Handling

### Domain Errors → App Errors

```swift
enum DomainError {
    case validationError(message: String)
    case logicError(message: String)
    case notFound(message: String)
}

enum AppError {
    case validationError(message: String)
    case databaseError(message: String)
    case logicError(message: String)
    // ...
    
    static func from(_ domainError: DomainError) -> AppError {
        switch domainError {
        case .validationError(let message):
            return .validationError(message: message)
        // ...
        }
    }
}
```

### User-Facing Errors

Ошибки преобразуются в понятные сообщения на уровне UI:

```swift
catch let error as AppError {
    showAlert(error.userFacingMessage)
}
```

## Logging

### Использование

```swift
let logger = LoggingService.shared
let correlationID = UUID().uuidString

logger.info("Creating motor", correlationID: correlationID)
logger.warning("Potential duplicate found", correlationID: correlationID)
logger.error("Failed to save", error: error, correlationID: correlationID)
```

### Логи пишутся:
- В консоль (OSLog)
- В файл (`~/Library/Application Support/AutoCore/logs/app.log`)

## Anti-Duplicate Service

### Проверка дубликатов

```swift
let service = AntiDuplicateService(motorRepository: repository)
let duplicates = try service.checkDuplicates(dto)

if !duplicates.isEmpty {
    // Показать пользователю для подтверждения
    showDuplicateWarning(duplicates)
}
```

### Алгоритм сравнения:
- Serial Code (exact = 0.4, fuzzy = 0.2)
- Engine ID (exact = 0.3)
- Arrival Date (same day = 0.3, same month = 0.15)

Порог схожести: **70%**

## Запрещенные практики

❌ **Бизнес-логика во ViewModel**
```swift
// ПЛОХО
class MotorViewModel {
    func sellMotor() {
        if motor.soldDate != nil { // Domain Rule в ViewModel!
            return
        }
        // ...
    }
}
```

✅ **Правильно**
```swift
// ХОРОШО
class MotorViewModel {
    func sellMotor() {
        do {
            try sellMotorUseCase.execute(motorID: motor.id)
        } catch {
            showError(error)
        }
    }
}
```

❌ **Прямой доступ UI к БД**
```swift
// ПЛОХО
struct MotorView: View {
    func save() {
        try database.insertMotor(...) // Прямой доступ!
    }
}
```

✅ **Правильно**
```swift
// ХОРОШО
struct MotorView: View {
    func save() {
        try createMotorUseCase.execute(dto)
    }
}
```

❌ **Валидация в UI**
```swift
// ПЛОХО
if serialCode.isEmpty {
    showError("Серийный номер обязателен") // Валидация в UI!
}
```

✅ **Правильно**
```swift
// ХОРОШО
do {
    try createMotorUseCase.execute(dto) // Валидация в Domain!
} catch let error as AppError {
    showError(error.userFacingMessage)
}
```

## Миграция существующего кода

### Шаг 1: Создать Use Case
```swift
// Было (в AppViewModel)
func addManualMotor(...) {
    try database.insertOrUpdateMotor(...)
}

// Стало
let useCase = CreateMotorUseCase(motorRepository: repository)
try useCase.execute(dto)
```

### Шаг 2: Обновить ViewModel
```swift
// Было
class AppViewModel {
    func addManualMotor(...) {
        // Бизнес-логика здесь
    }
}

// Стало
class AppViewModel {
    private let createMotorUseCase: CreateMotorUseCase
    
    func addManualMotor(...) {
        do {
            let dto = CreateMotorDTO(...)
            try createMotorUseCase.execute(dto)
            refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Шаг 3: Убрать прямые вызовы БД
```swift
// Было
try database.insertOrUpdateMotor(...)

// Стало
try motorRepository.save(entity)
```

## Расширяемость

### Добавление нового Use Case

1. Создать Use Case:
```swift
@MainActor
final class DeleteMotorUseCase {
    // ...
    func execute(motorID: Int64) throws {
        // ...
    }
}
```

2. Добавить Domain Event:
```swift
struct MotorDeletedEvent: DomainEvent {
    // ...
}
```

3. Использовать в ViewModel:
```swift
let useCase = DeleteMotorUseCase(...)
try useCase.execute(motorID: id)
```

### Добавление нового Domain Rule

1. Добавить в Entity:
```swift
struct MotorEntity {
    func validate() throws {
        // Новое правило
        guard condition else {
            throw DomainError.validationError(message: "...")
        }
    }
}
```

2. Правило автоматически применяется во всех Use Cases

## Готовность к коммерческому использованию

✅ **Чистая архитектура** - легко расширять и поддерживать  
✅ **Audit Log** - полная история изменений  
✅ **Миграции БД** - безопасное обновление схемы  
✅ **Error Handling** - централизованная обработка ошибок  
✅ **Logging** - структурированное логирование  
✅ **Anti-Duplicate** - защита от дубликатов  
✅ **Event-Driven** - готовность к интеграциям  
✅ **Domain Rules** - бизнес-логика в одном месте  

## Готовность к LLM и серверу

✅ **Event Bus** - легко добавить внешние подписчики  
✅ **Repository Pattern** - легко заменить БД на API  
✅ **Use Cases** - готовы к выносу в микросервисы  
✅ **Domain Events** - готовы к отправке на сервер  
✅ **Audit Log** - готов к синхронизации с сервером  
