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

## Backend hosting

Frawly has **no hosted Supabase project yet**. The org (`25sixela25@gmail.com's Org`) is on Supabase's free plan, capped at 2 active projects, and both slots are already used by SplitBalance (prod + staging) - creating a 3rd was attempted and rejected by the API when this app was built. See `env/README.md` for the full picture.

Practically, this means:

- `supabase/migrations/*.sql` is only ever applied to a **local** Supabase stack (`supabase start`, Docker) today - there is no staging/prod project to `supabase db push` to yet.
- `env/local.json` has real (public, non-secret) default local-dev credentials and works out of the box with `supabase start`.
- `env/staging.json` and `env/prod.json` are empty placeholders. Builds using them still succeed (Flutter doesn't validate `--dart-define` values at compile time), but the deployed app fails fast at startup with a clear "Missing Supabase config" error (see `main.dart`) until real values are filled in.
- The CI/CD workflow shape (`deploy.yml`, `deploy-main.yml`, `deploy-pr-preview.yml`, `release-apk.yml`) is otherwise identical to SplitBalance's, so wiring in a real project later is just filling in two JSON files and running the migrations against it - no workflow changes needed.

When a project slot frees up (new paid project, pausing/deleting one of SplitBalance's, or upgrading the org), fill in `env/staging.json`/`env/prod.json` and run the migrations against it. Until then, there's no `keep-supabase-staging-awake.yml`-style workflow here - nothing to keep awake.

## Avoid Postgres RPCs/schema migrations when a client-side query can do the job

There's no CI step or automation that applies `supabase/migrations/*.sql` to a staging or production Supabase project - it's a manual `supabase db push` someone has to run (and today, there isn't even a hosted project to push to - see "Backend hosting" above). Code that depends on a new migration (e.g. a new RPC function) will work locally but break against a hosted project (`PGRST202: Could not find the function ...`) until someone remembers to push it.

Prefer plain PostgREST queries (`.select()`, `.update().in_(...)`, `.upsert(..., onConflict: 'id', ignoreDuplicates: true)`, etc.) over a new RPC whenever one can do the job - see `lib/services/container_service.dart` for this pattern in practice (bulk filling/empty/add-range are all single atomic PostgREST requests, no RPC).

The one deliberate exception is `import_containers` (`supabase/migrations/20260917230100_import_replace_function.sql`): full-dataset import must atomically replace every row, and there's no single plain PostgREST request that expresses "delete everything, then insert this instead" as one transaction. Only reach for an RPC/migration when there's genuinely no client-side way to get the right answer like this - and flag explicitly (as here) that it needs a manual `supabase db push` before it'll work anywhere but locally.
