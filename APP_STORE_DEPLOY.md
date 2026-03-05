# Подготовка AutoCore к публикации в App Store

## Выполненные изменения

1. **Аутентификация**: только Sign in with Apple (Firebase и Supabase удалены).
2. **Роли**: Админ (полный доступ, ввод данных) и Бухгалтер (только раздел «Бухгалтерия»). Роль хранится в CloudKit.
3. **Обновления**: проверка и показ версий приложения удалены.
4. **Entitlements**: добавлены Sign in with Apple и iCloud (CloudKit).

---

## Как назначить роли по email (кто админ, кто бухгалтер)

Роли задаются **по Apple ID (email)** в CloudKit **Public** базе. Приложение сначала ищет запись по email, потом по внутреннему userId.

### Вариант А: Одной кнопкой из приложения (рекомендуется)

1. В CloudKit Dashboard создайте тип записи **UserRole** с полем **role** (String) и сохраните схему для **Public Database** (см. Шаг 2 ниже).
2. Запустите приложение, войдите (любым Apple ID).
3. Откройте **Настройки** → **Продвинутые** → секция **«Роли (CloudKit)»**.
4. Нажмите **«Создать записи ролей в CloudKit»**. Будут созданы записи для victhewise@icloud.com (бухгалтер) и iskanderamiri@icloud.com (админ).

Если появится ошибка прав доступа: в CloudKit Dashboard для типа **UserRole** в Public Database разрешите создание записей для аутентифицированных пользователей.

### Вариант Б: Вручную в CloudKit Dashboard

### Шаг 1: Откройте CloudKit Dashboard

1. Зайдите на [icloud.developer.apple.com](https://icloud.developer.apple.com/).
2. Выберите контейнер **iCloud.fise.AutoCore** (или ваш контейнер приложения).

### Шаг 2: Схема типа записи UserRole (Public Database)

1. Вкладка **Schema** → **Record Types**.
2. Если типа **UserRole** нет — нажмите **+** и создайте:
   - **Record Type**: `UserRole`
   - **Fields**: добавьте поле `role` (String).
3. Убедитесь, что тип **UserRole** доступен для **Public Database** (в настройках типа зоны).

### Шаг 3: Создайте записи ролей в Public Database

1. Перейдите в **Data** → выберите **Public Database** (не Private).
2. Выберите зону **Default Zone**.
3. Выберите тип записей **UserRole** (или нажмите **+** для новой записи).

**Бухгалтер (victhewise@icloud.com):**

- Нажмите **+** (новая запись).
- **Record Name**: введите **точно** (можно в нижнем регистре):  
  `victhewise@icloud.com`
- В поле **role** (String): `accountant`
- Сохраните.

**Админ (Iskanderamiri@icloud.com):**

- Ещё одна новая запись.
- **Record Name**: `iskanderamiri@icloud.com`  
  (приложение приводит email к нижнему регистру, можно так и задать).
- В поле **role** (String): `admin`
- Сохраните.

Итого в Public Database будут две записи типа **UserRole**:

| Record Name              | role       |
|--------------------------|------------|
| victhewise@icloud.com    | accountant |
| iskanderamiri@icloud.com| admin      |

### Важно

- Email должен совпадать с тем, который пользователь передаёт при **Sign in with Apple** (тот, что привязан к Apple ID). Обычно это тот же iCloud-адрес.
- Регистр букв в Record Name не важен — приложение сравнивает email в нижнем регистре.
- Если записи для email нет, используется роль **Бухгалтер** по умолчанию.

---

## Настройка CloudKit (общее)

1. В [Apple Developer](https://developer.apple.com/account) → Identifiers → App ID → включите **Sign in with Apple** и **iCloud** (CloudKit).
2. В CloudKit Dashboard для контейнера приложения:
   - Тип записи **UserRole** в **Public Database** с полем `role` (String) — см. выше.
   - Роли по email задаются в **Public Database**; при необходимости можно использовать и **Private Database** по userId (Record Name: `UserRole-<userId>`).

## Чек-лист перед отправкой в App Store

- [ ] В Xcode: выбран правильный **Team** и **Signing & Capabilities** (Sign in with Apple, iCloud с CloudKit).
- [ ] В App Store Connect создано приложение (macOS), заполнены метаданные и скриншоты.
- [ ] **Privacy**: при использовании CloudKit и Apple ID добавьте описание в раздел «Privacy» в App Store Connect и при необходимости обновите Privacy Manifest в проекте.
- [ ] **Export Compliance**: если приложение не использует шифрование кроме стандартного (HTTPS, Apple), можно указать «No» в Export Compliance.
- [ ] Архив: Product → Archive → Distribute App → App Store Connect.

## Идентификатор контейнера CloudKit

В коде используется контейнер: `iCloud.fise.AutoCore`. Если ваш Bundle ID или iCloud container другой, измените строку в `CloudKitAuthService.swift`:

```swift
self.container = CKContainer(identifier: "iCloud.fise.AutoCore")
```

Соответствующий контейнер должен быть создан в Capabilities и в CloudKit Dashboard.
