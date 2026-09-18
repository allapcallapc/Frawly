# env/*.json

`--dart-define-from-file` configs for `lib/config/backend_config.dart`. Each
file only pre-fills the connect screen's URL field with that environment's
Worker - the app never auto-connects, and the passphrase is never baked into
a build (see `lib/services/backend_connection.dart`); it's entered once and
stored on-device from then on. See `backend/README.md` for how the backend
itself is deployed.

- `local.json` - points at `wrangler dev`'s default local address
  (`http://127.0.0.1:8787`, see `backend/README.md`). Passphrase is whatever
  `API_PASSPHRASE` is set to in `backend/.dev.vars`.
- `staging.json` / `prod.json` - placeholders (empty `BACKEND_URL`) until the
  `frawly-api` Worker has actually been deployed to that environment
  (`pnpm run deploy:staging` / `deploy:production` in `backend/`, or the
  `backend-deploy.yml` CI job). A build using an empty config still
  succeeds - the connect screen's URL field is just blank, so whoever runs
  the build fills in the real Worker URL themselves.

Once `wrangler deploy --env staging`/`--env production` has run at least
once, fill in that environment's `*.workers.dev` URL (or custom domain) here.
