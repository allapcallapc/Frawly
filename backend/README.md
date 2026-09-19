# Frawly backend

A Cloudflare Worker (Hono) + D1 (SQLite) REST API. The Flutter app talks to
this over HTTP - it never touches D1/Cloudflare directly, so the storage
layer can change later without the app noticing (see the root `CLAUDE.md`).

## Auth model

No multi-user accounts - a single shared passphrase, checked on every
request (`src/auth.ts`), keeps the app "just for me" instead of open to
anyone who finds the URL. Set via `wrangler secret put API_PASSPHRASE`
(never committed). The Flutter app's connect screen is where you enter it.

## One-time setup (once you have a Cloudflare account)

`wrangler.toml` is gitignored - only `wrangler.toml.example` (a template)
is committed - because it ends up holding your two D1 databases'
`database_id` values, and this repo keeps every deployment-specific
identifier out of source rather than deciding case-by-case which ones
technically count as secret (see `wrangler.toml.example`'s own comment:
these particular IDs aren't secret by themselves, but nothing here is
committed regardless). That means the IDs live in two places, both filled
in from the same `wrangler d1 create` output: your own `wrangler.toml` (for
deploying from your machine) and two GitHub repo secrets (for
`backend-deploy.yml` to deploy from CI).

```
cd backend
pnpm install
cp wrangler.toml.example wrangler.toml

# Create the two databases (staging/production - see wrangler.toml's
# comment for why there are two):
npx wrangler d1 create frawly-db-staging
npx wrangler d1 create frawly-db-production
```

Each command prints a `database_id`. Paste them into your own
`wrangler.toml`'s two `[env.*]` sections, **and** add them as GitHub repo
secrets `D1_STAGING_DATABASE_ID`/`D1_PRODUCTION_DATABASE_ID` (Settings >
Secrets and variables > Actions) - `backend-deploy.yml` templates them into
its own `wrangler.toml` at deploy time, the same way you just did by hand.

```
# Set the shared passphrase for each environment (pick your own value -
# this is what you'll type into the app's connect screen):
npx wrangler secret put API_PASSPHRASE --env staging
npx wrangler secret put API_PASSPHRASE --env production

# Apply the schema:
pnpm run migrate:staging
pnpm run migrate:production
```

Then add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as two more
GitHub repo secrets so `backend-deploy.yml` can deploy automatically:
staging on every push to main AND on every PR touching `backend/**` (so a
migration/deploy problem shows up on the PR itself, not only after
merging), production on every published release.

## Local development

No Cloudflare account needed for this part:

```
pnpm install
cp wrangler.toml.example wrangler.toml   # skip if you already have one
pnpm run migrate:local   # applies migrations/ to a local SQLite file
pnpm run dev              # wrangler dev on http://127.0.0.1:8787
```

Local dev reads `API_PASSPHRASE` from `.dev.vars` (gitignored - create it
yourself, e.g. `echo "API_PASSPHRASE=dev-secret" > .dev.vars`).

## Tests

`pnpm test` spawns a real `wrangler dev` against a throwaway local D1
database and exercises the HTTP API end-to-end - see `test/api.test.ts`'s
own comment for why this doesn't use `@cloudflare/vitest-pool-workers`.
