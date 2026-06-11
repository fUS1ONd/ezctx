---
phase: 09-keypool-concurrency
plan: "01"
subsystem: core/error
tags: [error-handling, sealed-class, dart, keypool, deepgram]
dependency_graph:
  requires: []
  provides: [KeyExhaustedException]
  affects:
    - lib/features/transcription/chunked_transcription_controller.dart
    - lib/features/transcription/key_pool.dart
tech_stack:
  added: []
  patterns: [sealed-class-extension, exhaustive-switch]
key_files:
  modified:
    - lib/core/error/app_exception.dart
decisions:
  - "KeyExhaustedException следует паттерну AllKeysBlockedException: позиционный необязательный super.message"
  - "Ветка KeyExhaustedException() в switch размещена рядом с AllKeysBlockedException"
  - "userMessage статичен, без интерполяции ключа (T-09-01-I mitigate)"
metrics:
  duration: "2m"
  completed_date: "2026-06-09T19:55:22Z"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
---

# Phase 09 Plan 01: KeyExhaustedException — добавление в sealed AppException Summary

KeyExhaustedException добавлен в sealed-иерархию AppException с ветками в exhaustive switch для Deepgram HTTP 402.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Добавить KeyExhaustedException и ветку в switch | e124fae | lib/core/error/app_exception.dart |

## What Was Built

Добавлен класс `KeyExhaustedException extends AppException` — нормализованное исключение для случая исчерпания кредитов API-ключа (Deepgram HTTP 402). Класс следует паттерну `AllKeysBlockedException`: позиционный необязательный `super.message` с дефолтным русским текстом, без именованных параметров.

В extension `AppExceptionUserMessage` добавлена ветка `KeyExhaustedException()` с статичным русским сообщением «Кредиты API-ключа исчерпаны. Добавьте ключ с активным балансом.» — без интерполяции значения ключа (T-09-01-I).

Комментарий класса указывает: Deepgram HTTP 402, Groq никогда не бросает. Exhaustive switch остаётся полным.

## Verification

- `flutter analyze lib/core/error/app_exception.dart` — No issues found
- sealed switch исчерпывающий: компилятор не выдаёт «not exhaustively matched»
- userMessage для KeyExhaustedException не содержит значения ключа

## Deviations from Plan

Незначительное: в docstring `AllKeysBlockedException` обновлена ссылка `GroqKeyPool` → `KeyPool` (соответствует переименованию фазы 09 из RESEARCH.md). Это не изменение поведения, только точность комментария.

## Known Stubs

Нет. KeyExhaustedException полностью реализован. Подключение к контроллеру и пулу — задачи планов 09-02 и 09-03.

## Threat Flags

Нет новых поверхностей. T-09-01-I (Information Disclosure) — mitigated: userMessage статичен.

## Self-Check: PASSED

- [x] `lib/core/error/app_exception.dart` — существует, содержит `class KeyExhaustedException`
- [x] Commit e124fae — существует
- [x] flutter analyze — No issues found
- [x] Ветка `KeyExhaustedException()` в switch — присутствует
