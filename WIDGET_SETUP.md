# Виджеты AutoCore Accounting

Всё находится в `AutoCoreAccountingWidget/`:

- **AutoCoreAccountingWidget.swift** — малый виджет (круговая диаграмма Касса/Kaspi), большой (столбчатая диаграмма за 7 дней)
- **AutoCoreAccountingWidgetBundle.swift** — точка входа @main
- **Info.plist** — NSExtension, CFBundleExecutable и др.
- **Assets.xcassets** — иконки, цвета
- **AutoCoreAccountingWidget.entitlements** — App Group

## App Group

Оба target должны иметь **App Groups** с `group.kz.autocore.accounting`:
- AutoCoreAccounting
- AutoCoreAccountingWidgetExtension

## Добавление виджета

Долгое нажатие на рабочий стол → **+** → **AutoCore** → малый или большой виджет.
