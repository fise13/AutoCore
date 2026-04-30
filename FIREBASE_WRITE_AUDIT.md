# Аудит и оптимизация Firestore write (AutoCore)

## Область аудита

- Платформа: iOS/macOS SwiftUI
- База: Firestore
- Цель: только write-операции (`setData`, `updateData`, `addDocument`, `delete`, `batch`, `transaction`)
- Главный риск-зона: каталог моторов (`brands`/`engines`/`motors`) и частые refresh-потоки

---

## Часть 1. Текущие write-точки

| Место | Тип write | Триггер | Кол-во write за вызов | Потенциальная проблема |
|---|---|---|---:|---|
| `AutoCore/Infrastructure/Firestore/FirestoreCatalogSyncService.swift` `pushSnapshot` | `batch.setData` + `batch.commit` | `AppViewModel.refreshAll()` | `brands.count + engines.count + motors.count` (обычно 1000–2000+) | Массовая перезапись всего каталога даже при точечном изменении |
| `AutoCore/Infrastructure/Firestore/FirestoreCatalogSyncService.swift` `pushSnapshot` | `batch.commit` (один batch) | То же | 1 commit на весь набор | Лимит Firestore 500 операций в batch: при 1000+ элементов commit может падать |
| `AutoCore/Infrastructure/Firestore/FirestoreCatalogSyncService.swift` `deleteMissingDocuments` | `batch.deleteDocument` + `batch.commit` | После `pushSnapshot` | До числа удаляемых документов | Доп. write-волна после каждого sync |
| `AutoCore/ViewModels/AppViewModel.swift` `refreshAll` -> `firestoreCatalogSync.pushSnapshot` | косвенно массовый `batch.setData` | Старт, sell/refund, add/update, batch-операции, rename и др. | См. выше | Частые вызовы `refreshAll()` мультиплицируют массовый sync |
| `AutoCore/Infrastructure/Firestore/FirestoreFinancialSyncService.swift` `pushOperation` | `setData` | Создание/синк финансовой операции | 1 | Нормально, но может вызываться сериями |
| `AutoCore/Infrastructure/Firestore/FirestoreFinancialSyncService.swift` `updateOperation` | `updateData` | Редактирование финоперации | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreFinancialSyncService.swift` `deleteOperation` | `delete` | Удаление финоперации | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreFinancialSyncService.swift` `pushLocalOperationsToFirestore` | `setData` в цикле | Фоновый push локальных операций | До `localOps.count` (лимит выборки 2000) | Пиковая write-нагрузка в фоне |
| `AutoCore/Infrastructure/Database/Repositories/FinancialOperationRepositoryImpl.swift` `save` | асинхронный `financialSync.pushOperation` | Создание операции | 1 cloud write + локальная БД | Дубликаты при повторных ретраях/гонках возможны |
| `AutoCore/Infrastructure/Database/Repositories/FinancialOperationRepositoryImpl.swift` `update` | асинхронный `financialSync.updateOperation` | Обновление операции | 1 | Зависит от наличия `cloudDocumentId` |
| `AutoCore/Infrastructure/Database/Repositories/FinancialOperationRepositoryImpl.swift` `deleteAll` | цикл `deleteOperation(documentId:)` | Очистка бухгалтерии | До числа облачных операций | Массовый burst write/delete |
| `AutoCoreAccounting/AppIOS/InvoiceScanConfirmService.swift` `confirmInvoice` | `documents/{id}.setData` | Подтверждение скана | 1 | Нормально |
| `AutoCoreAccounting/AppIOS/InvoiceScanConfirmService.swift` `markMatchedMotorsAsSold` | `batch.updateData` + `batch.commit` | Продажная накладная (сопоставление моторов) | До числа matched моторов | Безопасно, но burst при массовом матчинге |
| `AutoCore/Infrastructure/Firestore/FirestoreInventoryRepository.swift` `save` | `setData(merge:true)` | CRUD склада | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreInventoryRepository.swift` `delete` | `delete` | Удаление склада | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreInventoryRepository.swift` `resolveCompanyId` | `users/{uid}.setData(merge:true)` | Почти любой вызов репозитория до кеша | 1 доп. write | Лишние служебные write в `users` |
| `AutoCore/Infrastructure/Firestore/FirestoreInventoryMovementRepository.swift` `save` | `setData(merge:true)` | Движение склада | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreInventoryMovementRepository.swift` `resolveCompanyId` | `users/{uid}.setData(merge:true)` | До кеша companyId | 1 доп. write | Лишние служебные write |
| `AutoCore/ViewModels/IOSAccountingViewModel.swift` `ensureFinancialWriteAccess` | `users/{uid}.setData(merge:true)` | Перед записью операций (если companyId не совпал) | 0/1 | Дополнительный write перед бизнес-write |
| `AutoCore/Infrastructure/Auth/FirebaseAuthService.swift` `updateProfile` | `updateData` | Изменение имени | 1 | Нормально |
| `AutoCore/Infrastructure/Auth/FirebaseAuthService.swift` `syncCompanyIdToFirestoreIfNeeded` | `setData(merge:true)` | Синк companyId | 1 | Нормально |
| `AutoCore/Infrastructure/Auth/FirebaseAuthService.swift` `deleteAccount` | `delete` | Удаление аккаунта | 1 | Нормально |
| `AutoCore/Infrastructure/Auth/FirebaseAuthService.swift` `loadUserEntity` | `setData` / `setData(merge:true)` | Первый вход / repair owner | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreCompanyService.swift` `createCompany` | `addDocument` | Создание компании | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreCompanyService.swift` `ensureDefaultCompany` | `setData` | Создание default-компании | 0/1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreCompanyService.swift` `assignUserToCompany` | `updateData` или `setData` | Привязка пользователя | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreInviteService.swift` `createInvite` | `addDocument` | Генерация invite-кода | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreInviteService.swift` `markInviteUsed` | `updateData` | Использование invite | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreInviteService.swift` `deleteInvite` | `delete` | Удаление invite | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreTaskService.swift` `createTask` | `addDocument` | Создание задачи | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreAccountRepository.swift` `save` | `setData(merge:true)` | Создание/апдейт счета | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreAccountRepository.swift` `updateBalance` | `runTransaction` + `transaction.setData` | Изменение баланса | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreOperationRepository.swift` `save` | `setData(merge:true)` | CRUD операции | 1 | Нормально |
| `AutoCore/Infrastructure/Firestore/FirestoreEngineRepository.swift` `save` | `setData(merge:true)` | CRUD двигателя | 1 | Нормально |

### Что может вызываться многократно

- `AppViewModel.refreshAll()` вызывается во многих сценариях, и тянет `pushSnapshot`.
- `pushSnapshot` перезаписывает **все** `motors`/`engines`/`brands` при изменившемся fingerprint.
- `resolveCompanyId` в inventory-репозиториях может добавлять служебный write в `users/{uid}`.
- В Excel UI фактическая запись в Firestore не на каждый символ (сохранение по явному действию), но downstream refresh-сценарии могут снова триггерить массовый sync.

---

## Часть 2. Проблемы и влияние

### 1) Массовая перезапись каталога вместо дельты
- **Где:** `FirestoreCatalogSyncService.pushSnapshot`
- **Почему плохо:** при изменении 1 мотора отправляется до 1000–2000+ документов.
- **Влияние:** `high`

### 2) Нарушение лимита batch (500 операций)
- **Где:** тот же `pushSnapshot`, один `db.batch()` на весь массив.
- **Почему плохо:** commit может падать, синк нестабилен при реальных объемах.
- **Влияние:** `high`

### 3) Слишком частый запуск полного sync через `refreshAll`
- **Где:** `AppViewModel.refreshAll()` (много точек вызова).
- **Почему плохо:** даже незначительные UX-действия могут вызывать дорогую cloud-перезапись.
- **Влияние:** `high`

### 4) Лишние служебные write в `users/{uid}`
- **Где:** `resolveCompanyId` и `ensureFinancialWriteAccess`.
- **Почему плохо:** +1 write до бизнес-операции, шум и лишняя стоимость.
- **Влияние:** `medium`

### 5) Массовые циклические write/delete без throttling
- **Где:** `pushLocalOperationsToFirestore`, `deleteAll`.
- **Почему плохо:** burst-нагрузка, риск квот/latency spikes.
- **Влияние:** `medium`

### 6) Политика “sync после refresh”, а не “sync после change-set”
- **Где:** архитектура AppViewModel + FirestoreCatalogSyncService.
- **Почему плохо:** синк связан с ререндер/перезагрузкой данных, а не с фактом изменения.
- **Влияние:** `high`

---

## Часть 3. Практическая оптимизация

## 1) Архитектура записи: от full snapshot к delta writes

### Сейчас
- `refreshAll()` -> `pushSnapshot(brands, engines, motors)` -> массовый batch.

### Целевой подход
- Писать в Firestore **только изменённые сущности** (insert/update/delete по одному документу или чанками).
- Сохранять `updatedAt` и sync только если локальный `updatedAt` новее remote.
- Убрать вызов полного `pushSnapshot` из общего refresh-потока.

Минимальный шаг без переписывания:
- оставить `pushSnapshot` только как “manual repair/resync” (кнопка или редкий maintenance),
- в обычных CRUD-сценариях писать только affected doc(s).

## 2) UI: локальное состояние и save по действию

- Для Excel/grid уже есть хороший фундамент: локальные draft + `Save`.
- Закрепить правило: Firestore write только из explicit save/use-case, не из `onChange` рендера.
- Не вызывать `refreshAll()` после каждой мелкой правки, если можно локально обновить кэш.

## 3) Debounce (где добавить)

- Для путей, где ввод пользователя может запускать облачную запись (профиль/служебные sync), добавить debounce 300–800ms.
- Для каталогов лучше не debounce “всё подряд”, а копить `dirty IDs` и flush таймером.

Пример (Swift, копим ID и пишем дельтой):

```swift
final class MotorSyncBuffer {
    private var dirtyIDs = Set<Int64>()
    private var task: Task<Void, Never>?

    func markDirty(_ id: Int64, flush: @escaping ([Int64]) async -> Void) {
        dirtyIDs.insert(id)
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            let ids = Array(dirtyIDs)
            dirtyIDs.removeAll()
            await flush(ids)
        }
    }
}
```

## 4) Как снизить write в 5–20 раз

- Убрать full-snapshot из `refreshAll`.
- Перейти на документную модель `motors/{id}` + write только по changed IDs.
- Для массовых действий использовать chunked batch (по 400–450 операций).
- Удалить лишние `users/{uid}.setData` из частых путей (кешировать companyId дольше, писать только при реальном изменении).
- Добавить идемпотентность по fingerprint **на уровне документа**, не на уровне всего каталога.

## 5) Batch/Transaction: когда да/нет

### Использовать `batch`
- Массовые независимые изменения (например, массово отметить N моторов как sold).
- Всегда chunk <= 500 (рекомендация: 400–450 для запаса).

### Использовать `transaction`
- Когда важна read-modify-write атомарность (как `updateBalance`).

### Не использовать
- Для “перезаписать весь каталог” при каждом refresh.
- Для длинных циклов на 1000+ без чанков и контроля ошибок.

---

## Часть 4. Рекомендуемая схема данных

### Вариант A (рекомендуемый): документ на мотор

```text
companies/{companyId}/motors/{motorId}
  serialCode
  engineId
  configuration
  notes
  quantity
  transmission
  arrivalDate
  soldDate
  deletedAt
  updatedAt
```

Плюсы:
- Точечный update 1 документа.
- Легко делать пагинацию/индексы.
- Низкая стоимость при частых изменениях.

Минусы:
- Больше документов, нужна дисциплина индексов.

### Вариант B: один большой документ-массив

```text
companies/{companyId}
  motors: [ ...1000+ elements... ]
```

Плюсы:
- Простая начальная модель.

Минусы:
- Любое изменение = перезапись большого payload.
- Конфликты и лимиты размера документа.
- Худший вариант для вашего кейса.

---

## Часть 5. Идеальный flow

1. **Загрузка**: читаем motors по `companyId` (query + пагинация/фильтры).  
2. **Локальное редактирование**: пользователь меняет draft в памяти.  
3. **Трекинг изменений**: ведём `dirty motor IDs` + changed fields.  
4. **Сохранение**: по кнопке/explicit action отправляем только изменённые документы (или batch chunk).  
5. **Пост-обновление**: локально мержим ответ, без полного `refreshAll + full snapshot`.

---

## Часть 6. Оценка метрик

Ниже реалистичная оценка для каталога 1500 моторов, 80 engines, 20 brands:

- Текущий full snapshot: ~`1600` write за один sync.
- Если такой sync уходит даже 10 раз/день: ~`16,000` write/день.
- При 30 событиях/день: ~`48,000` write/день.

После дельта-подхода:
- 1 точечное редактирование мотора: `1` write (иногда 2 с audit-полем).
- 30 изменений/день: ~`30–60` write/день.

Ожидаемое снижение:
- от `~99%` в worst-case (48,000 -> 60),
- реалистично `80–98%` в зависимости от доли массовых операций.

---

## Быстрый план внедрения (без переписывания всего)

1. Вынести `pushSnapshot` из `refreshAll` (оставить только manual full-resync).  
2. Добавить `MotorCloudSyncService.saveMotorDelta(motor:)` и вызывать его из текущих save/use-case путей.  
3. В batch-операциях внедрить chunking по 400–450.  
4. Ограничить `users/{uid}.setData(companyId)` только когда значение реально изменилось и не закешировано.  
5. Включить write-метрики (счётчики вызовов по коллекциям) на 1–2 недели для валидации экономии.

