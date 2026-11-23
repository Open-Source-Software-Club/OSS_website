# Instructions for AI coding agents

This file is for AI assistants (Copilot, Claude, Cursor, Codex and others)
working in this repository, and for contributors who use them. Humans should
start with [CONTRIBUTING.md](CONTRIBUTING.md); everything here is consistent
with it.

## Before you change anything

- Work on an issue that is **assigned to the person you are helping**. If it is
  not, tell them to comment `/assign` on it first — unassigned work is how two
  pull requests end up building the same thing.
- Read the specification for the area you are touching: [docs/PRD.md](docs/PRD.md),
  [docs/architecture.md](docs/architecture.md),
  [docs/DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md),
  [docs/UI_UX_SPECIFICATION.md](docs/UI_UX_SPECIFICATION.md).

## Conventions CI enforces (a pull request that breaks one cannot merge)

- **Package manager:** pnpm only. Never create `package-lock.json`, `yarn.lock`
  or `bun.lock*`, and never run `npm install`/`yarn`.
- **Branch name:** `<type>/<short-description>`, lowercase, e.g.
  `feat/events-rsvp-button`. Types: `feat fix docs style refactor perf test build ci chore revert`.
- **Commit messages and the pull-request title:** Conventional Commits,
  `<type>(<optional scope>): <subject>` with a lowercase subject of at most 72
  characters and no trailing period.
- **Pull-request description:** fill in the template and include
  `Closes #<issue>`.
- **Text files:** LF line endings, no trailing whitespace, no tabs, one final
  newline ([.editorconfig](.editorconfig)).
- **No secrets, ever:** no `.env*` files, keys or tokens in any file. Use
  `process.env` and document new variables in `.env.example`.
- **No files over 1 MiB, and no build output** (`.next/`, `node_modules/`,
  `coverage/`, …).
- **GitHub Actions:** pin every `uses:` to a full commit SHA with the version in
  a trailing comment (`@<40-hex-sha> # v1.2.3`); never interpolate
  `${{ github.event.* }}` into a `run:` block — pass it through `env:`.

## Check your work before proposing it

```bash
./scripts/checks/run-all.sh          # the repository gate, same as CI
pnpm lint && pnpm typecheck && pnpm test && pnpm build   # once the app exists
```

Report the result honestly in the pull request's *How Has This Been Tested?*
section. Do not claim a check passed if you did not run it.

## Keep the change small

One issue per pull request. Above 400 changed lines the PR check warns, and
above 10,000 lines or 300 files it fails. Do not reformat, rename or "tidy"
files that the issue does not require you to touch.

## Ownership

[`.github/CODEOWNERS`](.github/CODEOWNERS) decides who must review each path.
Changes under `.github/`, `scripts/`, `supabase/` and the security-sensitive
modules listed there need a technical lead; expect a closer review and explain
the reasoning in the description.
