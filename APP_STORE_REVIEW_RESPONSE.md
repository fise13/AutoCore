# Ответы для App Store Review (Submission ID: 9c40845c-d70d-45d4-b64d-4d4d4cd3380f)

## Guideline 2.1(b) — Business Model

**Ответ на английском (вставить в App Store Connect → Resolution Center):**

> **1. Who are the users that will use the paid subscriptions, features, and services in the app?**
>
> AutoCore does NOT offer paid subscriptions, in-app purchases, or any paid digital content. The app is free to use. All features (cash tracking, Kaspi balance, expenses, income, team sync, widgets) are available to all users at no cost.
>
> **2. Where can users purchase the subscriptions, features, and services that can be accessed in the app?**
>
> N/A — There are no purchases. The app is completely free.
>
> **3. What specific types of previously purchased subscriptions, features, and services can a user access in the app?**
>
> N/A — No paid content.
>
> **4. What paid content, subscriptions, or features are unlocked within the app that do not use In-App Purchase?**
>
> None. All features are free. There is no paid content.
>
> **5. Are the enterprise services in your app sold to single users, consumers, or for family use?**
>
> N/A — AutoCore is a free small-business accounting app. It is not sold. Users sign up for free and use the app to track cash, Kaspi, and expenses for their business or personal use.

---

## Guideline 5.1.1(v) — Account Deletion

**Ответ:**

> Account deletion has been added in version 2.0.
>
> **Location:** Profile screen → "Удалить аккаунт" (Delete Account) section at the bottom.
>
> **Path:** Tab "Ещё" (More) → tap profile icon/name → Profile screen → scroll down → "Удалить аккаунт" → tap → confirm in alert.
>
> The deletion permanently removes the user's Firestore profile document and Firebase Auth account. A confirmation alert prevents accidental deletion.

---

## Guideline 2.1(a) — Demo Account

**Действия:**

1. **Создать демо-аккаунт** в Firebase Auth (email/password) с предзаполненными данными:
   - Email: `demo@autocore.app` (или ваш домен)
   - Password: (надёжный пароль, указать в App Review Information)

2. **В App Store Connect** → Ваше приложение → App Store → [версия] → **App Review Information**:
   - **Sign-in required:** Yes
   - **Demo account:**
     - Username: `demo@autocore.app`
     - Password: `[ваш пароль]`

3. **Предзаполнить данные** для демо-аккаунта в Firestore:
   - Создать компанию
   - Добавить несколько операций (приходы, расходы, продажи)
   - Чтобы ревьюер видел полный функционал

4. **Notes for reviewer** (в том же разделе):
   ```
   Demo account has pre-populated data: cash operations, expenses, income.
   Path: Sign in → Dashboard (main tab) → Operations tab for full list.
   Account deletion: More tab → Profile → scroll down → "Удалить аккаунт".
   ```

---

## Checklist перед повторной отправкой

- [ ] Добавлена функция удаления аккаунта (сделано в коде)
- [ ] Создан демо-аккаунт с email/password
- [ ] В Firestore предзаполнены данные для демо-аккаунта
- [ ] В App Review Information указаны логин и пароль демо-аккаунта
- [ ] В Resolution Center отправлены ответы на вопросы 2.1(b)
- [ ] Указано расположение функции удаления аккаунта
