# CLAUDE.md

Guidance for Claude Code when working in this repository.

## PR titles must follow Conventional Commits

Releases are automated by [release-please](https://github.com/googleapis/release-please-action) (`.github/workflows/release-please.yml`), which decides the next version and writes the changelog by parsing commit messages - specifically the PR title, since PRs are squash-merged into a single commit.

Every PR title must start with one of:

- `fix: ...` - bug fix, bumps the patch version (0.1.0 -> 0.1.1)
- `feat: ...` - new feature, bumps the minor version (0.1.0 -> 0.2.0)
- `feat!: ...` or `fix!: ...` - breaking change, bumps the major version (0.1.0 -> 1.0.0)
- `chore: ...`, `refactor: ...`, `docs: ...`, `test: ...`, `ci: ...` - no version bump, but still recorded

A PR title without one of these prefixes won't be picked up by release-please at all - the change merges normally but is invisible to the changelog/version bump.

## Release flow

1. Merging a correctly-titled PR updates release-please's running "Release PR" (changelog + next version).
2. Merging that Release PR is the only manual release step: it creates the release as a draft, `release-apk.yml` builds the APK and attaches it, then publishes the release, which triggers `deploy.yml` to deploy the web build to GitHub Pages.
3. Do not create GitHub Releases manually via the UI, and do not push tags directly - either bypasses release-please's version tracking and can conflict with GitHub's immutable-releases restriction (once a tag name has been used by a published release, it can never have a release re-attached to it, even if that release is deleted).

## Architecture: the app never talks to the data layer directly

The Flutter app (`lib/`) only ever speaks HTTP to a small backend-for-frontend
(`backend/`: a Cloudflare Worker running Hono, backed by D1/SQLite) - it has
no Supabase/Postgres/D1 client embedded in it, and no direct database
credentials. `lib/services/container_service.dart` is the *only* place that
makes network calls, and every one of them is a REST request to the Worker
(`GET/POST/PATCH/DELETE`, see `backend/src/index.ts` for the routes). This
means the storage layer can change again later (D1 -> something else)
without the app changing at all beyond `ContainerService`.

### Auth model

Single-user, not multi-tenant: one shared passphrase (`API_PASSPHRASE`, a
Wrangler secret - see `backend/README.md`) checked on every request
(`backend/src/auth.ts`). There's no sign-up/sign-in flow and no per-user
data isolation - this is intentionally "just for me," not a shared product.

The app itself never bakes a backend URL or passphrase into a build. Instead:

- `lib/services/backend_connection.dart` (`BackendConnection`) holds the
  currently-connected backend's URL + passphrase, persisted on-device via
  `flutter_secure_storage`.
- `lib/screens/connect_screen.dart` is shown whenever `BackendConnection` has
  nothing saved (first launch, or after disconnecting) - it verifies the
  URL/passphrase actually reach a Frawly backend (`GET /health`) before
  saving them.
- "Manage containers" has a "Backend" section with a **Disconnect** button
  (`lib/screens/manage_containers_screen.dart`), so you can switch backends
  (e.g. staging -> production) from within the app itself, not just at
  build time.
- `env/*.json`'s `BACKEND_URL` only *pre-fills* the connect screen's URL
  field for convenience (see `lib/config/backend_config.dart`) - it's never
  auto-connected, and the passphrase is never in `env/*.json` at all.

### Two environments: staging and production

Mirrors SplitBalance's prod/staging split, but with two D1 databases behind
one Worker (`backend/wrangler.toml.example`'s `[env.staging]`/`[env.production]`
- the real `wrangler.toml` is gitignored, see its own comment)
instead of two separate Supabase projects:

- `main` branch deploys are the staging preview app, pointed at the
  `frawly-api` Worker's `staging` environment (`env/staging.json`).
- Published releases deploy the production app, pointed at the
  `production` environment (`env/prod.json`).
- `backend-deploy.yml` deploys the Worker: `staging` on every push to
  `main` AND on every PR that touches `backend/**` (so a migration/deploy
  problem surfaces on the PR itself, against the real Cloudflare account,
  rather than only after merging), `production` on every published
  release - see `backend/README.md` for the one-time Cloudflare setup this
  needs (`CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID` repo secrets).

### Schema changes: D1 migrations, applied by CI

D1 migrations (`backend/migrations/*.sql`) run through `wrangler d1
migrations apply`, which `backend-deploy.yml` calls automatically against
the right environment before every deploy - so, unlike SplitBalance's
manual `supabase db push`, merging a PR that adds a migration is enough for
it to reach staging/prod; nobody has to remember a separate manual step.

### mcp-server/: another REST client, not another way into the data

`mcp-server/` (see its own README) exposes the backend as MCP tools for an
LLM client, deployed as its own Cloudflare Worker (reachable by URL, no
local process to run) - a third Worker alongside `frawly-api`'s
staging/production, with its own `wrangler.toml`/deploy workflow. It's a
peer of the Flutter app, not a shortcut around it: like
`lib/services/container_service.dart`, `mcp-server/src/client.ts` only ever
speaks the Worker's REST API (no direct D1 access), so a new capability
here means a new/changed Worker route (see the CLAUDE.md rule below) plus
a matching client method and tool - not a separate data path. It
deliberately doesn't expose `POST /import` (full-registry replace) as a
tool, since that's more destructive than an LLM client should be handed by
default.

### Avoid a new endpoint/migration when the existing ones can do the job

Prefer expressing a new client need as a call to an existing Worker route,
or a small addition to one, over a new bespoke endpoint - and prefer a
plain `UPDATE ... WHERE id IN (...)` / `INSERT ... ON CONFLICT` over
reaching for D1's `.batch()` transaction unless the operation genuinely
needs several statements to succeed or fail together (see
`backend/src/index.ts`'s `/fillings`, `/containers/empty`, and
`/containers/range` handlers, which are each a single statement, versus
`/import`, which genuinely needs `.batch()` to replace every row
atomically).

