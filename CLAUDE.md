

<!-- GSD:project-start source:PROJECT.md -->
## Project

**ezctx**

Кроссплатформенное (стартуем с Android) Flutter-приложение, которое локально извлекает текстовый контекст из аудио/видео через Groq Whisper API. Цель — за минуты получить готовую расшифровку на телефоне и сразу отдать её в LLM (ChatGPT/Claude) для дальнейшего анализа: поиска замечаний преподавателя, советов, выделения сути лекции.

**Core Value:** Пользователь записал лекцию на телефон → открыл ezctx → выбрал файл → через несколько минут получил готовый txt в буфере обмена или поделился в GPT. Без перегона жирного аудио на компьютер.

### Constraints

- **Tech stack**: Flutter (Dart) — единый кодбейз под Android/Windows/iOS, зрелый `ffmpeg_kit_flutter`, простой перенос React-дизайна.
- **Платформа v1**: только Android — собирается с Windows+WSL без Mac.
- **API**: только Groq Whisper (free tier), без серверной части.
- **Бюджет на распространение**: $0 на v1 (APK + бета через Firebase App Distribution), Google Play ($25 разово) — по необходимости.
- **Хранение секретов**: API-ключи только в `flutter_secure_storage`, никогда не в репозитории и не в сборке.
- **ffmpeg на Android**: через `ffmpeg_kit_flutter` (содержит ffmpeg + ffprobe).
- **Размер чанка**: ≤ 19 MB (баланс битрейта/длительности; базово 20 мин при mp3 128 kbps).
<!-- GSD:project-end -->

<!-- GSD:stack-start source:STACK.md -->
## Technology Stack

Technology stack not yet documented. Will populate after codebase mapping or first phase.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

## Context Window

Для команд с большим выводом ВСЕГДА используй `mcp__plugin_context-mode_context-mode__ctx_batch_execute` или `ctx_execute`. Никогда не запускай через Bash напрямую:
- `flutter test`, `flutter analyze`, `flutter build`, `flutter pub get`
- `find`, `grep` на большом дереве файлов
- `git log`, `git diff` с большим выводом

Bash разрешён только для: `git add/commit/push/checkout`, `mkdir`, `mv`, `rm`, `cp`.

## Releases

Релиз = push тега `vX.Y.Z` в `main`. Workflow `.github/workflows/release.yml` собирает 3 подписанных APK (по ABI) и публикует GitHub Release.

**Как сделать релиз (с любой машины, чистого чата):**

1. Убедиться, что на `main` и подтянут remote:
   ```
   git checkout main && git pull
   ```
2. Поднять версию:
   - в `pubspec.yaml` → строка `version: X.Y.Z+N` (где `N` = `versionCode`, инкрементируется на каждый релиз)
   - в `android/app/build.gradle` → `versionCode = N`, `versionName = "X.Y.Z"` (должны совпадать с pubspec)
3. Закоммитить и поставить тег:
   ```
   git commit -am "chore(release): vX.Y.Z"
   git tag vX.Y.Z
   git push origin main --tags
   ```
4. Workflow на тег запустится автоматически — проверить в Actions, что APK опубликованы на странице Releases.

Дебажные APK на каждый push/PR в `main` собирает `build-debug-apk.yml` (артефакт, без релиза).

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
