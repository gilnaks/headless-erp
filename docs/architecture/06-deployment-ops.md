# 06 — Environments, GitHub, Supabase, Netlify, Backups

## Environments

| Env | Supabase | Next.js | Branch |
|---|---|---|---|
| local | `supabase start` (Docker) — MCP at `http://localhost:54321/mcp` | `next dev` | feature branches |
| preview | Supabase **dev** project (shared) or Supabase Branching (if on Pro) | Netlify Deploy Preview per PR | PR |
| production | Supabase **prod** project | Netlify production site | `main` |

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

- Repo `headless-erp` (private), default branch `main`, protected: PR required, CI green, 1 review (or Bugbot) before merge.
- Conventional commits; PR template with a "ERPNext source files consulted" section and a checklist from `PLAN.md §8`.
- Labels per module; issues created per doctype from the module docs' checklists.
- Dependabot for npm + GitHub Actions.

### Workflows

`ci.yml` (on PR + push to main):
1. `npm ci`, `biome ci`, `tsc --noEmit`, `vitest run`.
2. `supabase start` → `supabase db reset` (applies all migrations + seed) → `supabase test db` (pgTAP) → `supabase gen types --local` and fail if `src/types/database.ts` is stale.
3. `next build` with `cacheComponents` on (catches dynamic-API misuse).
4. Playwright smoke on the built app against local Supabase (login → onboarding → create & submit a Sales Invoice → check GL report).

`deploy-db.yml` (on push to `main`, after `ci.yml`): `supabase link --project-ref $PROD_REF` → `supabase db push` (migrations only) → `supabase functions deploy` → `supabase gen types` sanity. Manual approval environment gate `production`.

`backup.yml` (nightly, `workflow_dispatch`):
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

- Env vars set per context (production / deploy-preview). Deploy previews point to the Supabase dev project.
- `proxy.ts` runs on Netlify Edge; keep it dependency-light (only `@supabase/ssr`).
- Content Security Policy added in P11 after inventorying third-party origins (Supabase URL, fonts).
- Scheduled work does **not** use Netlify functions; it uses `pg_cron` in Supabase (and Supabase Edge Functions for email) so the schedule survives independent of the web host.

## Observability

- Supabase logs via MCP `query_logs` during development; Postgres `log_min_duration_statement = 500ms` on dev.
- Next.js: `instrumentation.ts` with OpenTelemetry → Netlify logs (or Sentry if adopted later; env-gated).
- An `app.audit_log` table for security events (login from new device, role changes, permission edits, exports) with 1-year retention.

## Release checklist

1. `main` green, `get_advisors` clean, pgTAP green.
2. `deploy-db.yml` approved → migrations applied (they must be backward compatible with the still-running previous build: add columns nullable first, drop in a later release).
3. Netlify production deploy auto-triggered by the same push; verify `/health` route and a smoke login.
4. Tag `vX.Y.Z`, release notes grouped by module.
