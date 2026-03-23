# Tetra Agent — Infrastructure Learnings

Hard-won lessons from the Phase A build (2026-03-23). Reference these before setting up a new project.

---

## GitHub Actions + Claude Code Action

| Issue | Fix |
|-------|-----|
| OIDC auth fails | Add `id-token: write` to workflow permissions |
| `ANTHROPIC_API_KEY` not found | Pass as `with: anthropic_api_key:`, NOT `env:` |
| All tool calls denied (git, Write, Edit) | Add `--dangerously-skip-permissions` to `claude_args` |
| `additional_permissions` doesn't help | That input controls GitHub API scopes, not Claude Code tool permissions |
| Agent creates `claude/` branch prefix | Override in prompt: "Create branch: agent/{entry-id}" |
| `max_turns`, `model` ignored as `with:` inputs | Pass via `claude_args: --max-turns 25 --model claude-sonnet-4-6` |

## n8n on Railway

| Issue | Fix |
|-------|-----|
| Volume permission denied (EACCES) | Set `RAILWAY_RUN_UID=0` — n8n runs as `node` user, Railway volumes mount as root |
| `$env.*` blocked in expressions | Set `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` |
| API-imported workflows: webhooks return 404 | Add `webhookId` (UUID) to every webhook node before import, then restart n8n |
| Webhook still 404 after activation | Deactivate → reactivate, or restart the Railway service |
| Header Auth credential only supports 1 header | Bypass credentials — hardcode headers directly in HTTP Request node `headerParameters` |
| Workflow update via API rejects payload | Only send: `name`, `nodes`, `connections`, `settings`, `staticData`. Strip `tags`, `id`, `active`, `createdAt`, etc. |

## Supabase

| Issue | Fix |
|-------|-----|
| "Expected 3 parts in JWT" | You're using new-style keys (`sb_secret_*`). Get legacy JWT keys from Settings → API → "Legacy anon, service_role API keys" tab |
| "Invalid API key" from REST API | Supabase REST needs TWO headers: `apikey: <jwt>` AND `Authorization: Bearer <jwt>` |
| `pg_net` function signature mismatch | Use named args with casts: `net.http_post(url := '...'::text, body := payload::jsonb)` |
| pg_net 5-arg positional form fails | Use 2-arg named form instead (url + body). Don't pass params/headers/timeout as positional args |
| `pg_net` extension not enabled | Run `CREATE EXTENSION IF NOT EXISTS pg_net;` in SQL Editor first |

## GitHub PAT (Fine-Grained)

| Issue | Fix |
|-------|-----|
| `repository_dispatch` returns 403 | PAT needs **Read and write** on: Contents, Pull requests, AND Actions |
| Default permissions are Read-only | Must explicitly change each to "Read and write" in token settings |

## Credential Strategy

Don't use n8n's built-in Header Auth credentials for services needing multiple headers. Instead:

```
authentication: "none"
sendHeaders: true
headerParameters:
  parameters:
    - name: "apikey"
      value: "<jwt-key>"
    - name: "Authorization"
      value: "Bearer <jwt-key>"
```

This avoids the single-header limitation and makes debugging easier (headers visible in execution logs).
