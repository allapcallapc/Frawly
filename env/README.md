# env/*.json

`--dart-define-from-file` configs for `lib/config/supabase_config.dart`. See
CLAUDE.md's "Backend hosting" section for the full story; short version:

- `local.json` - points at the local Supabase stack (`supabase start`),
  using its fixed default demo anon key (public, documented by Supabase,
  not a secret). This is the only backend that actually exists right now.
- `staging.json` / `prod.json` - placeholders (empty strings) until a
  hosted Supabase project exists for Frawly. The org's free tier is
  already at its 2-project cap (used by SplitBalance's prod+staging), so
  there was no free slot to create one when this app was built. A build
  using an empty config still succeeds; the app just fails fast at startup
  with a clear "Missing Supabase config" error (see `main.dart`) until
  real values are filled in here.

Once a project exists (new paid project, a freed slot, or reusing one
project for both staging and prod), fill in its URL/anon key from
Project Settings > API and re-run the migrations in `supabase/migrations/`
against it (`supabase db push` - nothing applies them automatically, see
CLAUDE.md).
