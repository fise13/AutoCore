# 📦 Инструкция по распространению AutoCore

## Проблема: "Не удается открыть программу" на другом Mac

Приложение подписано сертификатом **"Apple Development"**, который работает только на том Mac, где оно было собрано.

## ✅ Решение 1: Сборка для распространения (рекомендуется)

### Вариант A: Использовать скрипт сборки

```bash
./build-for-distribution.sh
```

Скрипт создаст ZIP-архив с приложением, которое можно запустить на любом Mac.

### Вариант B: Сборка вручную через Xcode

1. Откройте проект в Xcode
2. Выберите схему **AutoCore** → **Release**
3. Product → Archive
4. После создания архива:
   - Нажмите **Distribute App**
   - Выберите **Copy App**
   - Сохраните `.app` файл

### Вариант C: Командная строка

```bash
xcodebuild \
    -project AutoCore.xcodeproj \
    -scheme AutoCore \
    -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Manual" \
    DEVELOPMENT_TEAM="" \
    ENABLE_HARDENED_RUNTIME=YES \
    -derivedDataPath ./build
```

Приложение будет в: `./build/Build/Products/Release/AutoCore.app`

---

## ✅ Решение 2: Обход Gatekeeper на целевом Mac

Если у пользователя уже есть `.app` файл, он может обойти Gatekeeper:

### Способ 1: Через Finder (рекомендуется)

1. **Правый клик** на `AutoCore.app`
2. Выберите **"Открыть"** (Open)
3. В диалоге безопасности нажмите **"Открыть"** (Open)

### Способ 2: Через Terminal

```bash
# Удалить карантин (quarantine attribute)
xattr -cr /path/to/AutoCore.app

# Затем запустить
open /path/to/AutoCore.app
```

### Способ 3: Через System Settings

1. System Settings → Privacy & Security
2. Прокрутите вниз до секции "Security"
3. Если видите сообщение о блокировке AutoCore, нажмите **"Open Anyway"**

---

## 🔐 Настройки подписи в проекте

В файле `project.pbxproj` для Release конфигурации:

- `CODE_SIGN_IDENTITY = "-"` — ad-hoc подпись (без сертификата)
- `CODE_SIGN_STYLE = Manual` — ручная подпись
- `ENABLE_HARDENED_RUNTIME = YES` — включен Hardened Runtime

Это позволяет запускать приложение на любом Mac после обхода Gatekeeper.

---

## 📋 Чеклист для распространения

- [ ] Собрать Release версию с `CODE_SIGN_IDENTITY = "-"`
- [ ] Протестировать на том же Mac
- [ ] Создать ZIP архив
- [ ] Отправить пользователю
- [ ] Предоставить инструкцию по обходу Gatekeeper

---

## ⚠️ Важно

- **Apple Development** сертификат работает только на Mac разработчика
- **Ad-hoc подпись** (`CODE_SIGN_IDENTITY = "-"`) требует обхода Gatekeeper на целевом Mac
- **Apple Distribution** сертификат нужен для App Store или notarized distribution

---

## 🚀 Для production (будущее)

Если планируется массовое распространение:

1. Получить **Apple Distribution** сертификат
2. Настроить **notarization** через Xcode
3. Использовать **Developer ID** для распространения вне App Store
