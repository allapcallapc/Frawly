# Frawly - Freezer Log

A mobile-first Flutter web + Android app for tracking frozen meal-prep containers. Every container has a user-assigned id (e.g. `P-3`, `G-12`), a date, a status (vacant / frozen / under construction), and an ordered list of ingredients. All data lives in Supabase (Postgres + PostgREST) - there's no local-only storage, so the same data is visible from any device.

## Running locally

Backend: start the local Supabase stack (see `supabase/config.toml`) and run the app against it - see `CLAUDE.md`'s "Backend hosting" section for why this is the only backend that exists today.

```
supabase start
flutter run -d chrome --dart-define-from-file=env/local.json
```

Or use the `.vscode/launch.json` / `.claude/launch.json` configs, which do the same thing.

## Project structure

- `lib/models/` - `Container`, `Ingredient`, `ContainerStatus`
- `lib/services/` - `ContainerService`, the only layer that talks to Supabase
- `lib/providers/` - `ContainersProvider` (app state, via `provider`)
- `lib/screens/` - Home, New filling, Empty containers, Container detail, Manage containers, Summary
- `lib/widgets/` - shared UI (status badges, container list tiles, ingredient editors, the checkbox container selector)
- `supabase/migrations/` - schema (see `CLAUDE.md` for the "avoid RPCs" convention this follows)

## Releases

Automated via release-please - see `CLAUDE.md` for the full flow and PR title conventions.
