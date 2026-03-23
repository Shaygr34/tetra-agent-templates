# CLAUDE.md — Tetra Test Project
# Generated: 2026-03-23
# Dodeca · Tetra Channel

---

## YOUR ROLE

You are Claude Code working on the Tetra test project.
This is a minimal Next.js application used to validate the Tetra Agent pipeline.

---

## OPERATIONAL RULES

### Decision-Making Authority

**Proceed without asking:**
- File creation and modification within src/
- Installing standard npm packages
- Fixing lint/build errors
- Committing and pushing to feature branches
- Creating and updating markdown files in docs/

**Stop and ask:**
- Any changes to .github/workflows/
- Changes to CLAUDE.md, STATE.md
- Adding external services or API keys
- Anything that changes deployment config

### Git Configuration

```bash
git config user.email "shaygriever34@gmail.com"
git config user.name "Shay Griever"
```

### Commit Conventions

```
feat(scope): description
fix(scope): description
agent(type): description  — for automated agent changes
```

---

## AGENT MODE RULES

When executing as the Tetra Agent (triggered by GitHub Actions):

1. **Read AGENT_LOG.md first** — understand what previous agent runs have done.
2. **Read the action items** from the prompt or specs/action-items/ directory.
3. **One branch per execution** — name it `agent/{entry-id-short}`.
4. **Implement conservatively** — prefer small, focused changes over large refactors.
5. **Never modify STATE.md** — that's the planning layer's responsibility.
6. **Always append to AGENT_LOG.md** before committing.
7. **Commit conventions:** `agent(type): description`
8. **Open PR with structured body.**
9. **If a task is ambiguous or risky, skip it** and note in PR body.
10. **Never push to main** — always create a PR.
