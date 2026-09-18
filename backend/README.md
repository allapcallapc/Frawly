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

```
cd backend
pnpm install

# Create the two databases (staging/production - see wrangler.toml's
# comment for why there are two) and paste their IDs into wrangler.toml:
npx wrangler d1 create frawly-db-staging
npx wrangler d1 create frawly-db-production

# Set the shared passphrase for each environment (pick your own value -
# this is what you'll type into the app's connect screen):
npx wrangler secret put API_PASSPHRASE --env staging
npx wrangler secret put API_PASSPHRASE --env production

# Apply the schema:
pnpm run migrate:staging
pnpm run migrate:production
```

Then add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as GitHub repo
secrets so `backend-deploy.yml` can deploy automatically (staging on every
push to main, production on every published release).

## Local development

No Cloudflare account needed for this part:

```
pnpm install
pnpm run migrate:local   # applies migrations/ to a local SQLite file
pnpm run dev              # wrangler dev on http://127.0.0.1:8787
```

Local dev reads `API_PASSPHRASE` from `.dev.vars` (gitignored - create it
yourself, e.g. `echo "API_PASSPHRASE=dev-secret" > .dev.vars`).

## Tests

`pnpm test` spawns a real `wrangler dev` against a throwaway local D1
database and exercises the HTTP API end-to-end - see `test/api.test.ts`'s
own comment for why this doesn't use `@cloudflare/vitest-pool-workers`.
