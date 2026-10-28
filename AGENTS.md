# AGENTS.md

## What this is

Single-package Flutter app (UI text in **Portuguese**): a weekly study planner
("Escopo semanal"). No monorepo, no CI, no Makefile/task runner, no `opencode.json`.
Toolchain: Flutter 3.47.5 stable, Dart SDK `^3.13.2`, `flutter_lints` via
`analysis_options.yaml` (platform dirs excluded from analysis).

## Commands

- `flutter pub get` — after any `pubspec.yaml` change
- `flutter analyze` — lint **and** typecheck; no separate typecheck step
- `flutter test` — one file: `flutter test test/widget_test.dart`; one case: `flutter test -n "<name>"`
- `flutter run` — needs a device/emulator (sqflite is mobile-only; no FFI set up)
- Verification order: `flutter analyze` → `flutter test`

Known state as of 2026-10-26 (verify, may have changed):

- `flutter analyze` reports 6 infos + 1 warning: deprecated `withOpacity`,
  `DropdownButtonFormField.value`, `ReorderableListView.onReorder`; `_MondayDate`
  naming; unused import in the test.
- `flutter test` **fails out of the box**: `test/widget_test.dart` is the leftover
  template counter test with its `pumpWidget` call deleted. Rewrite it rather than
  debugging it.

## Architecture

- `lib/main.dart` (~700 lines) holds nearly everything: `StudyBlock`/`BlockStatus`
  model, `WeeklyScopePage` UI, block dialog, drag/swipe widgets. State is plain
  `setState`; no routing, no state-management package.
- `lib/database.dart` — `DatabaseHelper` singleton over sqflite (`nortis.db`,
  schema v1, single `blocks` table). **No migrations exist**; schema changes need
  a `version` bump + `onUpdate`.
- Persistence keys are data, not display strings: `weekKey` = Monday of the week
  formatted `YYYY-MM-DD` (`_MondayDate` in `main.dart`), `day` = Portuguese weekday
  name (`'Segunda'`…`'Domingo'`). Never translate or rename them — they are stored
  in DB rows.
- `BlockStatus` is persisted as an enum index, but no UI can change it today, so
  the progress bar is permanently 0% until a "mark as done" action is added.
- `database.dart` imports `main.dart` for the model (circular by design); splitting
  the model into its own file is the expected first refactor.

## Planned work (read before large changes)

`docs/superpowers/specs/2026-10-26-dashboard-lateral-design.md` (status: awaiting
approval) plans a `NavigationRail` + `IndexedStack` shell with Daily/Weekly/Monthly
scopes and a proposed `lib/` layout (`scopes/`, `models/`, `widgets/`). Follow its
file layout and its verification bar (`flutter analyze` clean + `flutter test`
passing) if implementing it. It explicitly rules out new schema/migrations.

## Testing quirks

- Pumping the real app in a widget test hits sqflite's MethodChannel from
  `initState` → `MissingPluginException`. Mock `DatabaseHelper` (the spec calls
  for a mocked `loadWeek`) or use `sqflite_common_ffi` — don't add it as a
  dependency without checking with the user.

## Git quirks

- Current branch is `prototype` (others: `main`, `develop`). History contains an
  abandoned Android/Kotlin Compose prototype — ignore it; the tree is Flutter-only.
- `.gitignore` is the old Android template's: `.dart_tool/` and
  `.flutter-plugins-dependencies` are **tracked**, so any Flutter command dirties
  `git status`. That noise is expected — don't commit it as part of your change.
