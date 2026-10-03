# AGENTS.md - Genus

Shared brief for every AI tool working in this repo (Claude, ChatGPT/Codex). Keep it current.

## Scope
- This repo holds Genus Medical Fertility (GM V1 Ltd) apps only. Do not copy code, data or keys between this repo and any other.
- Supabase: the Genus Supabase project only.

## How to work
- Work on a branch named `claude/<task>` or `codex/<task>`. Never commit to `main`. Scott merges.
- One AI per branch. Do not edit another AI's open branch.
- Keep changes inside the app folder you were asked to work on.
- Update `REGISTER.md` when an app is added, moved, renamed or retired.
- Use plain, simple wording in UI text and docs. Metric units only.

## Secrets
- Never commit keys, tokens, passwords or service_role keys. Secrets live in the password manager vault for this bucket.
- Supabase anon/publishable keys are public by design and may go in config files.

