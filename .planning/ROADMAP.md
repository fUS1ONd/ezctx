# ROADMAP — Интеграция Deepgram nova-3

**Майлстоун:** второй движок распознавания (Deepgram nova-3) рядом с Groq Whisper.
**Источник дизайна:** `docs/superpowers/specs/2026-06-08-deepgram-nova3-integration-design.md`
**Ветка:** `feat/deepgram-nova3`
**Разлочено в фазы:** 2026-06-08

> Спека согласована как источник истины и сознательно меняет 3 задокументированных
> ограничения `CLAUDE.md` (Groq-only → 2 провайдера; mp3 32k → opus 48k/.ogg;
> порог 4920 → ~3240). `CLAUDE.md` обновляется через `dscs-updater` по ходу фаз 08 и 10.

## Фазы

### 07 — Provider-абстракция + рефактор Groq  `[refactor]`
Интерфейс `TranscriptionProvider`, `GroqProvider` из `GroqApiService`, новые enum'ы
(`TranscriptionProviderId`/`TranscriptionModel`/`TranscriptionOptions`) + миграция
хранилища. Поведение не меняется. **Фундамент.**
Зависимости: нет. → `07-SPEC.md`
**Планы:** 2 плана (2 волны)
Планы:
- [x] 07-01-PLAN.md — Модель данных: TranscriptionProviderId/TranscriptionModel + миграция хранилища
- [x] 07-02-PLAN.md — Интерфейс TranscriptionProvider + рефактор GroqApiService→GroqProvider (поведение 1:1)

### 08 — Нормализация opus + чанкинг  `[refactor]`
`AudioNormalizationService` на opus 48k/.ogg, `.ogg`-сегментация, пересчёт порога
(`~3240`), проверка libopus (fallback mp3 64k), MIME через провайдера.
Зависимости: 07. → `08-SPEC.md`
**Plans:** 4 plans (waves: 1=01/02/03 parallel, 2=04)
- [x] 08-01-PLAN.md — нормализация opus 48k/.ogg + тесты
- [x] 08-02-PLAN.md — порог 3240 + сегментация .ogg + тесты (VBR-граница)
- [x] 08-03-PLAN.md — MIME audio/ogg в GroqProvider + Wave 0 MIME-тест
- [x] 08-04-PLAN.md — CLAUDE.md (dscs-updater) + зачистка downstream-тестов + phase gate

### 09 — Обобщённый KeyPool + ошибки + конкурентность  `[refactor]`
`GroqKeyPool`→`KeyPool`, `ExhaustedKeyStatus`/`reportExhausted`, нормализованные
исключения (`KeyExhaustedException` и др.), `concurrencyFor`, провайдеро-независимый
контроллер.
Зависимости: 07. → `09-SPEC.md`
**Plans:** 3 plans (3 waves)
- [x] 09-01-PLAN.md — `KeyExhaustedException` + ветка exhaustive switch (R-08)
- [x] 09-02-PLAN.md — `GroqKeyPool`→`KeyPool` rename + `ExhaustedKeyStatus`/`reportExhausted`/`_isAlive` + немедленный `AllKeysBlockedException` (R-01..R-05)
- [x] 09-03-PLAN.md — провайдеро-независимый контроллер + ветка `KeyExhaustedException` + `.ogg` fix + helpers-extraction + `concurrencyFor` тесты (R-06..R-09)

### 10 — DeepgramProvider + DI-проводка  `[feature]`
Новый `DeepgramProvider` (raw bytes, парсинг `paragraphs`/`words`, маппинг кодов),
namespace-хранилище, второй пул, выбор `provider+pool` по `options.model.provider`,
`ChunkedMissingKey`. Nova-3 работает end-to-end.
Зависимости: 07, 08, 09. → `10-SPEC.md`
**Plans:** 4 plans (waves: 1=01/02 parallel, 2=03, 3=04)
Plans:
- [ ] 10-01-PLAN.md — DeepgramProvider (raw-bytes nova-3, парсинг paragraphs/words, маппинг кодов) + Wave 0 тесты/фикстуры (R-DG-01..05)
- [ ] 10-02-PLAN.md — namespace-хранилище: параметризация SecureStorageServiceImpl + Deepgram DI-двойники storage/repo (R-DG-07)
- [ ] 10-03-PLAN.md — второй пул в DI + bootstrap + выбор provider+pool в ProcessingScreen + ChunkedMissingKey (R-DG-06, R-DG-08)
- [ ] 10-04-PLAN.md — фазовый гейт (full suite, R-DG-07) + обновление CLAUDE.md через dscs-updater

### 11 — UI: выбор провайдера/языка + раздельные ключи  `[feature/UI]`
Функциональный контракт + UI/UX-агент (liquid glass). Выбор модели/языка, два набора
ключей, статус «исчерпан».
Зависимости: 10. → `11-SPEC.md`
**Plans:** 4 plans (waves: 1=01/02 parallel, 2=03, 3=04)
Plans:
- [x] 11-01-PLAN.md — KeyStatusTile ветка ExhaustedKeyStatus + LiquidGlassTabBar text-only (nullable icon)
- [x] 11-02-PLAN.md — NoKeysDialog параметризация (Groq-дефолт + Deepgram-вариант, обратная совместимость)
- [x] 11-03-PLAN.md — ApiKeysScreen → TabBar Groq/Deepgram (раздельные repo/pool) + app.dart routing (initialTab)
- [x] 11-04-PLAN.md — SettingsScreen: nova3 в пикере, мультипровайдерная StatusCard, NoKeysDialog-проводка, ru-плюрализация

### 12 — Валидация тестов (Nyquist)  `[test]`
Ревью осмысленности тест-кейсов + граничные случаи по фазам 07–11. Запуск через
`/gsd-validate-phase`.
Зависимости: 07–11. → `12-SPEC.md`

## Граф зависимостей

```
07 ─┬─ 08 ─┐
    ├─ 09 ─┼─ 10 ── 11 ── 12
    └──────┘
```

## Следующий шаг

`/gsd-execute-phase 11` — исполнить планы фазы 11 (UI: выбор провайдера/языка + раздельные ключи).
