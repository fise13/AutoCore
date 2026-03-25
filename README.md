# AutoCore

**Учёт денег, кассы, Kaspi и расходов для малого бизнеса.**  
Приложение для macOS и iOS с облачной синхронизацией, командной работой и виджетами на главный экран.

---

## Содержание

- [Возможности](#возможности)
- [Платформы](#платформы)
- [Стек и зависимости](#стек-и-зависимости)
- [Требования](#требования)
- [Установка и запуск](#установка-и-запуск)
- [Структура проекта](#структура-проекта)
- [Архитектура](#архитектура)
- [Firebase и бэкенд](#firebase-и-бэкенд)
- [Разработка](#разработка)
- [Публикация](#публикация)
- [Дополнительная документация](#дополнительная-документация)

---

## Возможности

### Денежная позиция и операции
- **Касса и Kaspi** — балансы в реальном времени, приходы, расходы, продажи, возвраты, переводы.
- **Операции** — полная история с фильтрацией и поиском.
- **Расходы по категориям** — еда, транспорт, покупки и прочее; настраиваемые категории.

### Учёт моторов (macOS)
- **Склад** — список моторов с фильтрами по бренду, двигателю, категории.
- **Проданные** — архив проданных с возможностью вернуть в продажу.
- **Связь с финансами** — продажа мотора создаёт операцию в бухгалтерии.

### Аналитика и отчёты
- **Динамика за 7 дней** — график операций за неделю.
- **KPI и сводки** — обзор по вкладкам «Обзор», «Касса», «Расходы», «Операции».
- **Экспорт** — Excel/CSV (на macOS), настраиваемые периоды и форматы.

### Синхронизация и команда
- **Облако** — данные в Firebase Firestore, доступ с нескольких устройств.
- **Компания** — мультитенантность: одна компания на аккаунт, роли (owner, admin, accountant, viewer).
- **Приглашения** — коды приглашения, присоединение по коду (Cloud Function).
- **Участники** — просмотр списка участников компании (для owner/admin).

### Виджеты (iOS)
- **Малый виджет** — круговая диаграмма «Касса / Kaspi» или расходы по категориям за день.
- **Большой виджет** — столбчатая диаграмма операций за 7 дней.
- Данные через **App Group** (`group.kz.autocore.accounting`).

### Безопасность и данные
- **Вход** — Sign in with Apple, Google Sign-In.
- **Права** — Firestore Rules и custom claims (companyId, role) через Cloud Function `syncUserClaims`.
- **Резервные копии** — создание, восстановление, управление бэкапами (macOS).

---

## Платформы

| Продукт | Платформа | Описание |
|--------|-----------|----------|
| **AutoCore** | macOS | Основное приложение: моторы, бухгалтерия, импорт/экспорт Excel, настройки, бэкапы. |
| **AutoCoreAccounting** | iOS | Мобильное приложение: дашборд, операции, бухгалтерия, профиль, приглашения, настройки. |
| **AutoCoreAccountingWidgetExtension** | iOS | Виджеты на главный экран (WidgetKit). |

Общий код (домен, слой приложения, репозитории, часть UI) живёт в папке **AutoCore** и подключается к iOS-таргету через общий проект.

---

## Стек и зависимости

- **Язык:** Swift  
- **UI:** SwiftUI  
- **Минимальные версии:** macOS 26.2, iOS 18.5 (или 26.2 для виджетов/тестов — см. проект).  

### Внешние пакеты (Swift Package Manager)

- **Firebase** (firebase-ios-sdk) — Auth, Firestore, Functions, Analytics, Crashlytics и др.
- **Google Sign-In** (GoogleSignIn-iOS) — вход через Google.
- **CoreXLSX** — чтение/запись Excel (.xlsx).
- **ZIPFoundation** — архивы (бэкапы и т.п.).

Зависимости заданы в `AutoCore.xcodeproj` и резолвятся в  
`AutoCore.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

---

## Требования

- **Xcode** — актуальная версия (поддерживающая выбранные deployment target).
- **macOS** — для сборки и запуска macOS-приложения.
- **Apple Developer Account** — для Sign in with Apple, Push (если понадобится), распространения.
- **Firebase проект** — для бэкенда (см. ниже).

---

## Установка и запуск

### 1. Клонирование и открытие проекта

```bash
git clone <url-репозитория> AutoCore
cd AutoCore
open AutoCore.xcodeproj
```

### 2. Firebase

- Создайте проект в [Firebase Console](https://console.firebase.google.com).
- Добавьте приложение **iOS** (Bundle ID для AutoCoreAccounting совпадает с тем, что в Xcode).
- Скачайте `GoogleService-Info.plist` и положите в каталог **AutoCoreAccounting** (и при необходимости настройте исключения в File System Sync для этого файла в Xcode).
- Включите **Authentication**: Sign-in with Apple, Google.
- Создайте базу **Firestore** и включите **Cloud Functions** (Node.js).

### 3. Firebase Rules и Functions

- Правила Firestore: `firebase/firestore.rules`
- Индексы: `firebase/firestore.indexes.json`
- Функции: `firebase/functions/`

Установка CLI и деплой:

```bash
npm install -g firebase-tools
firebase login
firebase deploy
```

Подробности по миграции с CloudKit и настройке бэкенда — в [FIREBASE_MIGRATION.md](FIREBASE_MIGRATION.md).

### 4. App Group (для виджетов)

Оба таргета должны иметь включённый **App Groups** с идентификатором:

- `group.kz.autocore.accounting`

Проверьте в Xcode: **Signing & Capabilities** для **AutoCoreAccounting** и **AutoCoreAccountingWidgetExtension**.

Подробнее: [WIDGET_SETUP.md](WIDGET_SETUP.md).

### 5. Схемы и запуск

- **AutoCore** — запуск macOS-приложения.
- **AutoCoreAccounting** — запуск iOS-приложения (симулятор или устройство).
- **AutoCoreAccountingWidgetExtension** — собирается вместе с iOS-приложением.

Выберите нужную схему в Xcode и нажмите Run (⌘R).

---

## Структура проекта

```
AutoCore/
├── AutoCore.xcodeproj/
├── firebase.json
├── firebase/
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   └── functions/
│       └── index.js
├── AutoCore/                          # Общий код (macOS + iOS)
│   ├── AutoCoreApp.swift              # Точка входа macOS
│   ├── AppDelegate.swift
│   ├── Application/                   # Слой приложения
│   │   ├── Services/                  # Auth, Backup, Company, Invite, Task, FinancialSync, WidgetDataStore, ...
│   │   ├── UseCases/                  # CreateMotor, SellMotor, CreateSaleOperation, CreateExpenseOperation, ...
│   │   ├── Repositories/              # Интерфейсы репозиториев
│   │   ├── Errors/
│   │   ├── FeatureFlags/
│   │   ├── Recovery/
│   │   └── ...
│   ├── Domain/                        # Сущности, value objects, правила
│   │   ├── Entities/                  # MotorEntity, UserEntity, ...
│   │   └── ValueObjects/
│   ├── Infrastructure/                # Реализации
│   │   ├── Auth/                      # FirebaseAuthService
│   │   ├── Database/                  # SQLite, миграции, репозитории
│   │   ├── Firestore/                 # Firestore*-сервисы
│   │   └── ...
│   ├── ViewModels/                    # AppState, AppViewModel, AuthViewModel, AccountingViewModel, ...
│   ├── Views/                         # RootView, AccountingView, MotorListView, SettingsView, ...
│   ├── Components/                    # Sidebar, TopBar, StatCard, ...
│   ├── DesignSystem/                  # DSColors, типографика, отступы
│   ├── Models/                        # Motor, FinancialOperation, Brand, ...
│   └── Services/                      # DatabaseService, ExcelExportService, ...
├── AutoCoreAccounting/               # iOS-приложение
│   ├── AppIOS/                        # iOS-specific UI
│   │   ├── IOSAppRootView.swift
│   │   ├── IOSDashboardView.swift
│   │   ├── IOSAccountingTabView.swift
│   │   ├── IOSMoreTabView.swift
│   │   └── ...
│   ├── GoogleService-Info.plist
│   └── ...
├── AutoCoreAccountingWidget/         # Виджеты
│   ├── AutoCoreAccountingWidget.swift
│   ├── AutoCoreAccountingWidgetBundle.swift
│   └── Info.plist
├── AutoCoreAccountingTests/
├── AutoCoreAccountingUITests/
├── README.md
├── APP_STORE_CONNECT.md               # Тексты для App Store
├── FIREBASE_MIGRATION.md               # Миграция CloudKit → Firebase
└── WIDGET_SETUP.md                    # Настройка виджетов
```

---

## Архитектура

- **Domain** — сущности (Motor, User, FinancialOperation и т.д.), value objects, доменные ошибки. Без зависимостей от UI и инфраструктуры.
- **Application** — сервисы (Auth, Company, Invite, Backup, FinancialSync, …), use cases (создание мотора, продажа, создание операции и т.д.), интерфейсы репозиториев.
- **Infrastructure** — реализация репозиториев (SQLite), Firebase (Auth, Firestore), миграции БД.
- **Presentation** — ViewModels (AppState, AppViewModel, AccountingViewModel, …), SwiftUI Views, компоненты и дизайн-система.

Данные: локальная SQLite (моторы, операции, настройки) + синхронизация финансовых операций и метаданных компании с Firestore. Роли и привязка пользователя к компании хранятся в Firestore (`users/{uid}`) и в custom claims (через Cloud Function `syncUserClaims`).

---

## Firebase и бэкенд

### Firestore

- **users/{userId}** — профиль пользователя, `companyId`, `role`.
- **companies/{companyId}** — компания, `ownerId`.
- **financialOperations/{operationId}** — финансовые операции с `companyId`.
- **tasks/{taskId}** — задачи компании.
- **invites/{inviteId}** — приглашения с кодом, сроком действия, флагом `used`.

Правила доступа описаны в `firebase/firestore.rules` (проверка `companyId`, ролей, владельца компании для инвайтов и участников).

### Cloud Functions

- **syncUserClaims** — при изменении `users/{userId}` выставляет custom claims `companyId` и `role` для Firebase Auth.
- **joinCompanyWithInvite** — callable-функция: проверка кода приглашения, обновление `users/{userId}`, пометка инвайта как использованного.

Деплой: `firebase deploy` (из корня проекта, где лежит `firebase.json`).

---

## Разработка

### Горячие клавиши (macOS)

- **⌘N** — новый мотор  
- **⌘I** — импорт Excel  
- **⌘E** — экспорт Excel  
- **⌘S** — пометить как проданный  
- **⌘D** — дублировать мотор  
- **⌘Z** / **⌘⇧Z** — отмена / повтор  
- **⌘⇧T** — панель тестировщика  

### Панель тестировщика

Меню **Вид → Панель тестировщика** (или ⌘⇧T) открывает окно для отладки БД и сценариев (например, массовые операции, проверка данных).

### Тесты

- **AutoCoreAccountingTests** — unit-тесты.
- **AutoCoreAccountingUITests** — UI-тесты.

Запуск: в Xcode Product → Test (⌘U) с выбранной схемой AutoCoreAccounting (или нужной тестовой целью).

---

## Публикация

- Тексты для App Store (рекламный текст, описание, ключевые слова RU/EN) собраны в [APP_STORE_CONNECT.md](APP_STORE_CONNECT.md).
- Перед загрузкой в App Store Connect проверьте:
  - подпись и capabilities (Sign in with Apple, App Groups, при необходимости Push);
  - наличие `GoogleService-Info.plist` в iOS-таргете;
  - развёрнутые Firestore rules и Cloud Functions для продакшена.

---

## Дополнительная документация

| Файл | Описание |
|------|----------|
| [APP_STORE_CONNECT.md](APP_STORE_CONNECT.md) | Тексты для App Store (RU/EN), ключевые слова. |
| [FIREBASE_MIGRATION.md](FIREBASE_MIGRATION.md) | Миграция с CloudKit на Firebase (данные, отключение CloudKit). |
| [WIDGET_SETUP.md](WIDGET_SETUP.md) | Настройка виджетов и App Group. |

---

## Лицензия

Проприетарный проект. Все права сохраняются за автором/компанией.
