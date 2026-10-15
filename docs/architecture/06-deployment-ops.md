# 06 — Environments, GitHub, Supabase, Netlify, Backups

## Environments

| Env | Supabase | Next.js | Branch |
|---|---|---|---|
| local | `supabase start` (Docker) — MCP at `http://localhost:54321/mcp` | `next dev` | feature branches |
| preview | Supabase **dev** project (shared) or Supabase Branching (if on Pro) | Netlify Deploy Preview per PR | PR |
| production | Supabase **prod** project | Netlify production site | `main` |

Storage: the private `org-files` bucket and its `storage.objects` policies are created by migration `0118` (no dashboard setup per environment); see 02-database-conventions "Files (Storage)".

Secrets: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (new publishable key format), `SUPABASE_SERVICE_ROLE_KEY` (server-only), `SUPABASE_ACCESS_TOKEN` + `SUPABASE_DB_PASSWORD` + `SUPABASE_PROJECT_REF` (CI only), `EMAIL_PROVIDER_API_KEY`, `APP_URL`. Local values in `.env.local` (git-ignored); `.env.example` committed.

## Supabase MCP (Cursor)

`.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "supabase": {
      "url": "https://mcp.supabase.com/mcp?project_ref=<DEV_PROJECT_REF>&features=database,docs,development,debugging"
    },
    "supabase-local": {
      "url": "http://localhost:54321/mcp"
    }
  }
}
```

Rules for the agent: use the MCP for `list_tables`, `apply_migration` (dev/local only), `execute_sql` (read queries, test data), `get_advisors` (must be clean before merge), `generate_typescript_types`, `search_docs`. Production is **never** configured in Cursor's MCP; production changes go through CI. If a production project must be inspected, add it as a separate server with `&read_only=true`.

## GitHub

- Repo `gilnaks/headless-erp` (private; remote `origin`), default branch `main`. Workflow: one branch and one PR per item, squash-merged once CI (`quality` + `db-and-e2e`) and the Netlify deploy preview are green; never push to `main` directly. GitHub does not enforce this (see owner checklist step 2), so it is a team convention. The earlier history came from `smarty72/headless-erp` (kept locally as remote `smarty72`, not pushed to).
- Conventional commits; `.github/pull_request_template.md` has an "ERPNext source files consulted" section and the `PLAN.md §8` checklist.
- Labels per module; issues created per doctype from the module docs' checklists.
- Dependabot (`.github/dependabot.yml`): weekly npm (minor + patch grouped) and GitHub Actions updates.

### Workflows

`ci.yml` (on every PR + push to `main`; newer runs on the same ref cancel older ones):
1. Job `quality`: `npm ci`, `npx biome ci .`, `npm run typecheck`, `npm test` (Vitest, excludes `*.db.test.ts`).
2. Job `db-and-e2e` (one job so local Supabase starts once; CLI pinned to the `supabase` devDependency version):
   - `supabase start -x studio,imgproxy,edge-runtime,logflare,vector,supavisor,realtime,storage-api,mailpit` → `supabase db reset` (every migration from scratch + `supabase/seed.sql`, which is intentionally empty) → `supabase test db` (pgTAP via pg_prove).
   - Local URL and keys from `supabase status -o env` are exported as `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `APP_URL`.
   - `node scripts/check-types.mjs` regenerates types from the local DB and fails if `src/types/database.ts` is stale. The committed file comes from the dev project (hosted generator) while CI generates locally (the CLI's newer built-in generator), so the script normalises layout (Biome), drops the `__InternalSupabase` block, `ComputedFields` and generated columns, and treats `Record<PropertyKey, never>` as `never` before comparing; anything else (a missing column, function or type change) fails. On failure the generated file is saved to `test-results/database.generated.ts` (in the uploaded artifact). Locally without Docker: `npm run db:types:check -- --linked`.
   - `npm run test:db` (`vitest.db.config.ts` → `src/doctypes/doctypes.db.test.ts`): every registered descriptor has a matching `doctype_meta` row (table, module, submittable, title field; child tables with `parent_doctype` + `child_field`) and every field / list column exists (zero-row PostgREST select).
   - `npm run build` (`cacheComponents` on, catches dynamic-API misuse), then `npm run e2e`: Playwright (Chromium) starts `next start` and runs `e2e/smoke.spec.ts`: sign in → the `/setup` wizard creates an organization and its first company → New Company → Save → the company is in the list. Sign-up needs email confirmation, so `e2e/global-setup.ts` creates a confirmed user with the admin API. The HTML report and traces are uploaded as an artifact when the job fails. The smoke grows to "create & submit a Sales Invoice → check GL report" in P5.

`deploy-db.yml` (after `ci.yml` succeeds on `main`, or `workflow_dispatch`): job runs only when the repository variable `DEPLOY_DB_ENABLED` is `true`, in environment `production` (manual approval) → checkout the CI commit → `supabase link --project-ref $SUPABASE_PROJECT_REF` → `supabase db push --dry-run` → `supabase db push` (migrations only). `supabase functions deploy` is added when the first Edge Function exists. Until the owner completes the checklist below the workflow is skipped.

`backup.yml` (nightly, `workflow_dispatch`, not built yet; lands before the first production tenant):
- `supabase db dump --role-only` / `--schema-only` → commit to `backups/schema/` in a dedicated **private** `headless-erp-backups` repo (text diffs of schema drift are useful).
- `supabase db dump --data-only` (excluding `auth`, `storage` internals) → `gpg --symmetric` with `BACKUP_PASSPHRASE` → upload as a 90-day GitHub Actions artifact **and** to a Supabase Storage bucket `backups` (private) in a *different* Supabase project or an S3-compatible bucket. Never commit plaintext tenant data to git.
- Restore drill documented in `docs/runbooks/restore.md` and executed quarterly against a scratch project.

Supabase side: Pro plan → daily automatic backups + PITR enabled for prod. Org-level self-service export (ERPNext "Download Backups" equivalent) = Server Action producing a ZIP of CSVs for that org only (RLS-scoped), delivered via signed URL.

## Netlify

- Site connected to the GitHub repo; Next.js adapter auto-detected (do not pin the adapter version). Node 22.
- `netlify.toml`:

```toml
[build]
  command = "npm run build"
  publish = ".next"
[build.environment]
  NODE_VERSION = "22"
[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
    Referrer-Policy = "strict-origin-when-cross-origin"
    Permissions-Policy = "camera=(), microphone=(), geolocation=()"
```

- Env vars set per context (production / deploy-preview / branch-deploy) in the Netlify UI, never in `netlify.toml`. Deploy previews point to the Supabase dev project.
- `proxy.ts` runs on Netlify Edge; keep it dependency-light (only `@supabase/ssr`).
- Content Security Policy added in P11 after inventorying third-party origins (Supabase URL, fonts).
- Scheduled work does **not** use Netlify functions; it uses `pg_cron` in Supabase (and Supabase Edge Functions for email) so the schedule survives independent of the web host. Migrations enable the extension themselves (`create extension if not exists pg_cron`, `0114`) and register jobs with `cron.schedule`, so a new project needs no dashboard step; check jobs with `select * from cron.job` and runs with `cron.job_run_details`.

## Setup checklist (owner)

CI runs without any secrets. Deploys stay inert until these steps are done by the repo owner (`gilnaks`) in the GitHub UI:

1. ~~Repository~~: done, `gilnaks/headless-erp` (private).
2. **Branch protection** on `main`: not available. GitHub only offers branch protection and rulesets on private repositories with GitHub Pro (or Team); the API returned 403 for this repo. Until the plan is upgraded, "PR only, squash-merge after `quality` + `db-and-e2e` + the Netlify preview are green, no force pushes" is a convention we follow, not something GitHub enforces. If the plan is upgraded: Settings → Rulesets → require a PR, require status checks `quality` and `db-and-e2e`, require branches to be up to date, block force pushes.
3. **Production Supabase project**: create it (Pro plan for PITR), then in its dashboard enable the custom access token hook `app.custom_access_token_hook` (Auth → Hooks), set Site URL + redirect URLs to the production domain (`/auth/callback**`), configure SMTP, and enable leaked-password protection.
4. **GitHub environment** `production` (Settings → Environments) with required reviewers and deployment branch `main`. Environment secrets: `SUPABASE_ACCESS_TOKEN` (personal access token), `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF` (prod ref).
5. **Enable deploys**: repository variable `DEPLOY_DB_ENABLED=true` (Settings → Secrets and variables → Actions → Variables). The first run applies every migration to the empty prod project; check the dry-run output before approving.
6. ~~**Netlify site**~~: done, [astonishing-bunny-48ac2a.netlify.app](https://astonishing-bunny-48ac2a.netlify.app/) builds `main` (`/health` returns `{ "ok": true }`); it currently uses the dev project, so it is a preview until the production project exists. Build settings come from `netlify.toml`. Env vars per context:
   - production: prod `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `APP_URL` (production domain), `EMAIL_PROVIDER_API_KEY` when email lands;
   - deploy-preview / branch-deploy: the dev project (oxkskzguqlwicieorkvh) values, `APP_URL` unset (the app falls back to the request origin); add `https://deploy-preview-*--<site>.netlify.app/auth/callback**` to the dev project's redirect URLs.
7. Verify: open a PR → CI green + Netlify preview; merge → approve `deploy-db` → `/health` returns `{ ok: true }` on production.

## Observability

- Supabase logs via MCP `query_logs` during development; Postgres `log_min_duration_statement = 500ms` on dev.
- Next.js: `instrumentation.ts` with OpenTelemetry → Netlify logs (or Sentry if adopted later; env-gated).
- An `app.audit_log` table for security events (login from new device, role changes, permission edits, exports) with 1-year retention.

## Release checklist

1. `main` green, `get_advisors` clean, pgTAP green.
2. `deploy-db.yml` approved → migrations applied (they must be backward compatible with the still-running previous build: add columns nullable first, drop in a later release).
3. Netlify production deploy auto-triggered by the same push; verify `/health` route and a smoke login.
4. Tag `vX.Y.Z`, release notes grouped by module.
