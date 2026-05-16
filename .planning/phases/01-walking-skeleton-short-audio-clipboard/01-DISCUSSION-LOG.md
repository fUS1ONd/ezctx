# Phase 1: Walking Skeleton (Short Audio → Clipboard) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-16
**Phase:** 1-Walking Skeleton (Short Audio → Clipboard)
**Areas discussed:** GitHub CI/CD триггер, тип APK, доставка APK, локальное тестирование, статус репозитория, Flutter SDK

---

## GitHub CI/CD — Триггер сборки

| Option | Description | Selected |
|--------|-------------|----------|
| Push в main | Каждый коммит → debug APK | ✓ |
| Только при тегах (v*) | Сборка только при явном теге | |
| Push в main + теги | Debug на каждый коммит, release при теге | |

**User's choice:** При каждом пуше в main
**Notes:** Пользователь хотел сразу видеть, что ничего не сломалось; также интересовался эмулятором и локальным тестированием.

---

## Тип APK из CI

| Option | Description | Selected |
|--------|-------------|----------|
| Только debug APK | Не нужен keystore. Простая настройка. | ✓ |
| Release APK (подписанный) | Нужен keystore и секреты в GitHub. | |

**User's choice:** Только debug APK
**Notes:** В v1 нет необходимости в release, нет Google Play.

---

## Доставка APK

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub Artifacts | Прикрепляется к workflow run, скачивается вручную | ✓ |
| Firebase App Distribution | Автораздача тестерам | |
| GitHub Release | APK при теге | |

**User's choice:** GitHub Artifacts
**Notes:** Нулевая настройка, достаточно для одного разработчика.

---

## Локальное тестирование во время разработки

| Option | Description | Selected |
|--------|-------------|----------|
| Физический Android по USB | Реальное железо, нужен usbipd-win для WSL | ✓ |
| Android Emulator в VS Code | AVD через Android Studio, медленнее физика | |
| Оба варианта | Эмулятор для быстрых итераций, физик для финального теста | |

**User's choice:** Физический Android по USB
**Notes:** Пользователь изначально спрашивал про эмулятор, но предпочёл реальное устройство. usbipd-win — одноразовая настройка ~5 мин.

---

## Статус репозитория GitHub

| Option | Description | Selected |
|--------|-------------|----------|
| Уже существует | git@github.com:fUS1ONd/ezctx.git | ✓ |
| Нужно создать | Через gh CLI или вручную | |

**User's choice:** Уже существует
**Notes:** SSH-репозиторий fUS1ONd/ezctx уже создан.

---

## Flutter SDK

| Option | Description | Selected |
|--------|-------------|----------|
| Уже установлен в WSL | flutter doctor работает | |
| Ещё не установлен | CI сам устанавливает, локально — отдельно | ✓ |

**User's choice:** Ещё не установлен
**Notes:** Нужна установка Flutter локально в WSL. CI использует subosito/flutter-action.

---

## Claude's Discretion

- Конкретная версия Flutter (stable канал, последняя стабильная)
- Структура workflow файла с кешированием pub packages
- minSdkVersion — определить по зависимостям

## Deferred Ideas

- Эмулятор Android — пользователь предпочёл физическое устройство
- Firebase App Distribution — пока достаточно GitHub Artifacts
- Release APK + keystore — только для Google Play (v2+)
