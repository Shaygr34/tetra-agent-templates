# Tetra Agent Templates

Reusable infrastructure templates for the Tetra Agent pipeline — automated voice-to-code execution for client websites.

## Pipeline Overview

```
Client voice input → Supabase entry → n8n WF1 (Claude generates action items)
→ n8n WF2 (triggers GitHub Actions) → Claude Code creates branch + PR
→ n8n WF3 (Telegram notification with Merge/Reject)
→ Shay taps Merge → n8n WF4 (merges PR) → deployed
```

## Files

### GitHub Actions
| File | Purpose |
|------|---------|
| `.github/workflows/tetra-agent.yml` | GitHub Actions workflow triggered by `repository_dispatch`. Runs Claude Code with `--dangerously-skip-permissions` and opens a PR. |

### Agent Files (copy into each client repo)
| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project instructions + agent mode rules. Claude Code reads this first on every run. |
| `AGENT_LOG.md` | Append-only audit trail of all automated agent actions. |
| `STATE.md` | Project state managed by the planning layer. Agent never modifies this. |

### Supabase
| File | Purpose |
|------|---------|
| `sql/001_initial_schema.sql` | Full schema: clients, projects, entries, action_items, conversation_state, agent_executions. Includes RLS policies, indexes, triggers, and seed data. |

### n8n Workflows
| File | Purpose |
|------|---------|
| `n8n-workflows/wf1_new_entry_processor.json` | Supabase webhook → Claude API → generate action items → save to DB |
| `n8n-workflows/wf2_execution_trigger.json` | Fetch action items → build prompt → fire `repository_dispatch` |
| `n8n-workflows/wf3_pr_notification.json` | GitHub PR webhook → Telegram notification with Merge/Reject buttons |
| `n8n-workflows/wf4_telegram_approval.json` | Telegram button callback → merge or close PR via GitHub API |
| `n8n-workflows/wf5_agent_complete.json` | GitHub Actions completion callback → update entry status |

### Documentation
| File | Purpose |
|------|---------|
| `INFRA_LEARNINGS.md` | Critical gotchas and fixes discovered during Phase A build. Read before setting up. |

## Setup: New Client Project

### 1. Create the repo
```bash
npx create-next-app@latest client-project --typescript --tailwind --app --yes
cd client-project
```

### 2. Copy agent files
```bash
cp /path/to/tetra-agent-templates/.github/workflows/tetra-agent.yml .github/workflows/
cp /path/to/tetra-agent-templates/CLAUDE.md .
cp /path/to/tetra-agent-templates/AGENT_LOG.md .
cp /path/to/tetra-agent-templates/STATE.md .
```

Edit `CLAUDE.md` with project-specific instructions (tech stack, conventions, etc).

### 3. Push and add secrets
```bash
gh repo create client-project --public --source=. --push
gh secret set ANTHROPIC_API_KEY -R Shaygr34/client-project
gh secret set N8N_WEBHOOK_URL -R Shaygr34/client-project
```

Set `N8N_WEBHOOK_URL` to `https://n8n-production-6f55.up.railway.app`

### 4. Add GitHub webhook
```bash
gh api repos/Shaygr34/client-project/hooks -X POST \
  -H "Content-Type: application/json" \
  --input - <<< '{"config":{"url":"https://n8n-production-6f55.up.railway.app/webhook/github-pr","content_type":"json"},"events":["pull_request"],"active":true}'
```

### 5. Add project to Supabase
```sql
INSERT INTO projects (client_id, name, slug, github_repo, phase)
SELECT c.id, 'Client Project', 'client-project', 'Shaygr34/client-project', '4'
FROM clients c WHERE c.slug = 'client-slug';
```

### 6. Test
```sql
INSERT INTO entries (project_id, intent, mode, raw_transcript, status)
SELECT p.id, 'feature', 'feedback',
  'Add a contact form to the homepage',
  'new'
FROM projects p WHERE p.slug = 'client-project';
```

Watch the chain: Supabase → n8n WF1 → WF2 → GitHub Actions → PR → Telegram → Merge.

## Infrastructure

| Service | URL |
|---------|-----|
| n8n | `https://n8n-production-6f55.up.railway.app` |
| Supabase | `https://cjyjromcbepylsfbxmyd.supabase.co` |
| Telegram Bot | `@TetraDeca_bot` |

See `INFRA_LEARNINGS.md` for critical setup gotchas.
