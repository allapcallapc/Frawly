# Frawly

A mobile-first Flutter web + Android app for tracking frozen meal-prep containers. Every container has a user-assigned id (e.g. `P-3`, `G-12`), a date, a status (vacant / frozen / under construction), and an ordered list of ingredients. The app never talks to a database directly - every request goes through a small backend (a Cloudflare Worker + D1, see `backend/`) over HTTPS, gated by a single shared passphrase you enter once from the app's connect screen (see `lib/screens/connect_screen.dart`) and which is then stored on-device.

## Running locally

Backend: start the Worker locally (see `backend/README.md`), then run the app against it:

```
cd backend && pnpm install && pnpm run migrate:local && pnpm run dev
# in another terminal
flutter run -d chrome --dart-define-from-file=env/local.json
```

The app will show a connect screen on first launch - enter `http://127.0.0.1:8787` (pre-filled from `env/local.json`) and whatever `API_PASSPHRASE` is set to in `backend/.dev.vars`.

Or use the `.vscode/launch.json` / `.claude/launch.json` configs, which set the same `--dart-define-from-file`.

## Project structure

- `lib/models/` - `FreezerContainer`, `Ingredient`, `ContainerStatus`
- `lib/services/` - `BackendConnection` (stores/tests the connected backend's URL + passphrase) and `ContainerService` (the only layer that makes HTTP requests, all against the Worker's REST API)
- `lib/providers/` - `ContainersProvider` (app state, via `provider`)
- `lib/screens/` - Connect, Home, New filling, Empty containers, Container detail, Manage containers, Summary
- `lib/widgets/` - shared UI (status badges, container list tiles, ingredient editors, the checkbox container selector)
- `backend/` - the Cloudflare Worker (Hono) + D1 backend; see `backend/README.md`
- `mcp-server/` - an MCP server exposing the backend as tools for an LLM client (Claude Desktop, Claude Code, etc.); see `mcp-server/README.md`

## Releases

Automated via release-please - see `CLAUDE.md` for the full flow and PR title conventions.
