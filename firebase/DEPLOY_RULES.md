# Деплой правил Firestore

Чтобы склад и каталог работали, в Firebase должны быть задеплоены правила из `firestore.rules`.

## Способ 1: через Firebase CLI (предпочтительно)

В корне проекта (рядом с firebase.json) выполни:

```bash
firebase deploy --only firestore:rules
```

Если CLI не установлен: `npm install -g firebase-tools`, затем `firebase login`.

## Способ 2: вручную в консоли

1. Открой [Firebase Console](https://console.firebase.google.com) → проект **autocore-6066c**.
2. **Build** → **Firestore Database** → вкладка **Rules**.
3. Скопируй **весь** текст из файла `firebase/firestore.rules` в проекте.
4. Вставь в редактор правил в консоли (полная замена).
5. Нажми **Publish**.

## Проверка после деплоя

- В консоли Firestore → **Rules** убедись, что в коде есть функции `canReadByCompanyDoc` и `canWriteByCompanyDoc` — значит задеплоена актуальная версия.
- Убедись, что под которым залогинен в приложении — тот же, у кого в `users/{uid}` заполнен `companyId` (например uid `e2QoJJdWtDhFu701JDJI1Tg37Bz2` и companyId `16tCcq5JvOIGsiH6PYLL`).
- Перезапусти приложение и открой склад.

Если ошибка «Missing or insufficient permissions» остаётся:
- В консоли открой **Rules** → **Rules Playground**.
- Симулируй **get** документа из `inventoryItems` (или `brands`) с **Auth** = Custom (uid твоего пользователя, без claims). Если симуляция проходит — значит проблема может быть в токене (claims); если не проходит — правило всё ещё не выполняется (проверь, что в `users/{uid}` в базе есть поле `companyId`).
