# Contributing to the Open Source Software Club Website

First off, welcome and thank you for taking the time to contribute! 🎉

Whether you are a seasoned software engineer, an enthusiastic college student at **Sai Vidya Institute of Technology (SVIT)**, or making your very first open-source pull request, your contributions, ideas, and feedback are genuinely appreciated.

This repository powers the official website for the **Open Source Software Club @ SVIT Bengaluru**. By contributing here, you are helping build a platform that serves hundreds of students and showcases the power of collaborative software engineering.

---

## 📌 Table of Contents

- [Contribution Philosophy](#-contribution-philosophy)
- [Code of Conduct](#-code-of-conduct)
- [Finding an Issue](#-finding-an-issue)
- [Claiming an Issue](#-claiming-an-issue)
- [Local Development Setup](#-local-development-setup)
  - [1. Fork and Clone](#1-fork-and-clone)
  - [2. Install Dependencies](#2-install-dependencies)
  - [3. Configure Environment](#3-configure-environment)
  - [4. Create a Working Branch](#4-create-a-working-branch)
- [Coding Conventions & Architecture](#-coding-conventions--architecture)
  - [TypeScript Guidelines](#typescript-guidelines)
  - [Next.js App Router & React](#nextjs-app-router--react)
  - [Tailwind CSS & shadcn/ui](#tailwind-css--shadcnui)
  - [File and Directory Naming](#file-and-directory-naming)
- [Commit Conventions](#-commit-conventions)
- [Testing & Quality Verification](#-testing--quality-verification)
- [The Automated Gate](#-the-automated-gate)
- [Submitting a Pull Request](#-submitting-a-pull-request)
- [Review & Merge Process](#-review--merge-process)
- [First Contribution Walkthrough](#-first-contribution-walkthrough)
- [Common Pitfalls to Avoid](#-common-pitfalls-to-avoid)
- [Getting Help](#-getting-help)

---

## 🌟 Contribution Philosophy

We believe in **learning in public** and that **no contribution is too small**:
- **Code:** Bug fixes, new features, performance optimizations, accessibility improvements.
- **Documentation:** Fixing typos, expanding guides, translating content, improving docstrings.
- **Design & UI:** Improving responsive layouts, color contrast, micro-interactions, dark mode styling.
- **Quality Assurance:** Finding bugs, writing tests, reporting broken links, suggesting security enhancements.
- **Community:** Helping review pull requests, answering questions in discussions, mentoring newer peers.

---

## 📜 Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By contributing, you pledge to uphold an inclusive, welcoming, and harassment-free environment for all community members.

If you encounter or suspect inappropriate behavior, please report it privately following the instructions in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

---

## 🔍 Finding an Issue

Before writing any code, search existing issues to see what needs work:

1. Visit our **[GitHub Issues](https://github.com/Open-Source-Software-Club/OSS_website/issues)** page.
2. Filter issues by tags:
   - `good first issue` — Welcoming entry-level tasks ideal for newcomers.
   - `help wanted` — Triaged issues where maintainers need community assistance.
   - `bug` — Something isn't working as intended.
   - `documentation` — Improvements to README, guides, or code comments.
   - `enhancement` — Feature requests or performance improvements.
3. If you want to propose a new feature or report a new bug that doesn't have an issue yet, **please open an issue first** before opening a PR. This ensures your idea aligns with the project vision and avoids wasted effort.

---

## ✋ Claiming an Issue

To prevent duplicate effort and ensure fair opportunity:

1. Comment directly on the issue:
   > *"Hi maintainers! I would like to work on this issue. Please assign it to me."*
2. **Wait for a maintainer to assign the issue to you** before starting work.
3. If you get assigned to an issue and later realize you cannot complete it, please post a quick comment so another contributor can step in.
4. **Inactivity Policy:** If an assigned issue receives no updates, linked PR, or communication within **7 days**, maintainers reserve the right to unassign it and open it for others.

---

## 💻 Local Development Setup

### 1. Fork and Clone

1. Fork the repository to your personal GitHub account by clicking the **Fork** button at the top-right of the [repository page](https://github.com/Open-Source-Software-Club/OSS_website).
2. Clone your fork locally:
   ```bash
   git clone https://github.com/<YOUR-USERNAME>/OSS_website.git
   cd OSS_website
   ```
3. Add the official upstream repository as a remote:
   ```bash
   git remote add upstream https://github.com/Open-Source-Software-Club/OSS_website.git
   git remote -v
   ```

### 2. Install Dependencies

We use **pnpm** exclusively for package management:

```bash
# Verify pnpm is installed (v8 or v9 required)
pnpm -v

# Install project dependencies
pnpm install
```

> [!CAUTION]
> Do NOT run `npm install` or `yarn install`. Doing so generates conflicting lockfiles (`package-lock.json` or `yarn.lock`) and will cause automated CI workflows to fail.

### 3. Configure Environment

Copy the example environment configuration:

```bash
cp .env.example .env.local
```

For basic UI development, the default mock or placeholder values will suffice. For features requiring database authentication or dynamic Supabase queries, ask maintainers in the club Discord/discussions for development sandbox credentials.

### 4. Create a Working Branch

Always keep your `main` branch synchronized with `upstream/main`. Never commit feature work directly to `main`.

```bash
# Fetch latest changes from upstream
git fetch upstream

# Ensure you are on local main and up-to-date
git checkout main
git merge upstream/main

# Create and checkout your feature branch
git checkout -b <type>/<short-description>
```

#### Branch Naming Guidelines
Use descriptive names prefixed with the contribution category:
- `feat/homepage-hero` — A new feature
- `fix/navbar-mobile-toggle` — A bug fix
- `docs/setup-guide-refactor` — Documentation updates
- `style/card-hover-effects` — Pure UI/CSS adjustments
- `refactor/supabase-client-utils` — Code structure improvements without behavior changes
- `test/events-filter` — Adding or improving tests

The permitted prefixes are `feat`, `fix`, `docs`, `style`, `refactor`, `perf`,
`test`, `build`, `ci`, `chore` and `revert`, and the description is lowercase
with `-`, `_` or `.` as separators.

This is not only a local convention: a **`Branch naming` ruleset rejects a push**
from a branch that does not match, so you will find out either way. The git hook
tells you *how* to fix it; the ruleset is the backstop. Automation branches
(`dependabot/`, `arena/`, `renovate/`, …), `main` and the `release/`, `hotfix/`
and `support/` trains are exempt.

---

## 📐 Coding Conventions & Architecture

### TypeScript Guidelines
- Maintain strict type safety (`strict: true` in `tsconfig.json`).
- Avoid the `any` type at all costs. Use `unknown` with type guards if the type is indeterminate.
- Define shared interfaces and data models inside `src/types/`.
- Use explicit return types for non-trivial utility functions and server actions.

```typescript
// Good
interface ProjectCardProps {
  id: string;
  title: string;
  description: string;
  tags: readonly string[];
  starsCount?: number;
}

export function ProjectCard({ id, title, description, tags, starsCount = 0 }: ProjectCardProps): JSX.Element {
  // ...
}
```

### Next.js App Router & React
- **Server Components by default:** Keep components as React Server Components (RSC) unless interactivity is required.
- **Client Components:** Use `'use client'` at the top of the file only when utilizing React hooks (`useState`, `useEffect`, `useCallback`), custom event handlers, browser-only APIs (`window`, `localStorage`), or client libraries.
- Keep Client Components low in the component tree to maximize server-side rendering performance.
- Use Next.js `<Image>` from `next/image` for automatic optimization and `<Link>` from `next/link` for client-side navigation.

### Tailwind CSS & shadcn/ui
- Use Tailwind utility classes for styling. Avoid writing raw CSS in stylesheets whenever possible.
- Use the `cn()` utility function from `@/lib/utils` for conditional class joining and resolving Tailwind conflicts:
  ```typescript
  import { cn } from "@/lib/utils";

  interface BadgeProps {
    isActive?: boolean;
    className?: string;
  }

  export function Badge({ isActive, className }: BadgeProps) {
    return (
      <span className={cn("px-2.5 py-0.5 rounded-full text-xs font-medium", isActive ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground", className)}>
        {isActive ? "Active" : "Archived"}
      </span>
    );
  }
  ```
- Use components from `src/components/ui/` (shadcn/ui primitives based on Radix UI) to ensure full keyboard navigation, screen-reader support, and ARIA compliance.

### File and Directory Naming
- **React Components:** PascalCase (e.g., `EventCard.tsx`, `Navbar.tsx`).
- **Pages and Layouts:** Standard Next.js route file conventions (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`).
- **Hooks:** camelCase prefixed with `use` (e.g., `useDebounce.ts`, `useMediaQuery.ts`).
- **Utility modules:** kebab-case or camelCase (e.g., `format-date.ts`, `supabase.ts`).
- **Styles:** kebab-case (e.g., `globals.css`).

---

## 📝 Commit Conventions

We follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification. Every commit message must follow this structure:

```text
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### Allowed Types
| Type | Purpose | Example |
|:---|:---|:---|
| `feat` | Adding a new feature or functionality | `feat(events): add RSVP button and counter` |
| `fix` | Fixing a bug or unexpected behavior | `fix(auth): resolve redirect loop after login` |
| `docs` | Documentation-only updates | `docs(readme): add environment variables table` |
| `style` | Formatting, whitespace, semicolon changes (no code logic change) | `style(ui): format button padding and rounded corners` |
| `refactor`| Code change that neither fixes a bug nor adds a feature | `refactor(supabase): extract query client to helper` |
| `perf` | Code change that improves runtime performance | `perf(images): enable AVIF format in next.config` |
| `test` | Adding missing tests or correcting existing tests | `test(utils): add unit tests for date formatting` |
| `build` | Build system or external dependency changes | `build(next): enable the standalone output` |
| `ci` | CI configuration, workflows and the repository gate | `ci(e2e): pin the runner image for Playwright` |
| `chore` | Tooling or dependency updates that touch neither the app nor CI | `chore(deps): update tailwindcss to v3.4.1` |
| `revert` | Undoing an earlier change | `revert(events): remove the RSVP counter` |

GitHub's **Revert** button produces a branch named `revert-<number>-<branch>` and
a title `Revert "<original title>"`. Both are accepted as they are — you do not
need to rename anything to revert a pull request.

### Good Commit Message Example:
```text
feat(projects): add search filter by programming language

Allow visitors to filter projects showcase by language tags (TypeScript, Python, Go).
Includes keyboard navigation and empty-state messaging.

Closes #42
```

---

## 🧪 Testing & Quality Verification

Before committing and pushing your code, run the following verification steps locally. All of these checks are validated automatically in CI:

```bash
# 1. Check TypeScript types
pnpm typecheck

# 2. Check for ESLint warnings and errors
pnpm lint

# 3. Check code formatting against Prettier
pnpm format:check

# If format check fails, automatically format files:
pnpm format

# 4. Verify production build compiles without errors
pnpm build
```

---

## 🚦 The Automated Gate

Everything above is re-checked by CI, and CI adds checks that cannot run on your
machine alone. The full design lives in **[docs/CI_CD.md](docs/CI_CD.md)**.

### Install the hooks first

```bash
./scripts/install-hooks.sh
```

This points git at `.githooks/`, so the same checks that gate CI run before your
code ever leaves your machine:

| Hook | Blocks |
|:---|:---|
| `pre-commit` | secrets, `.env` files, foreign lockfiles, build output, oversized files, trailing whitespace, tabs, CRLF |
| `commit-msg` | commit messages that are not Conventional Commits |
| `pre-push` | direct pushes to `main`, plus a re-run of the file checks (secrets, forbidden and oversized files, whitespace, lockfiles) on the whole tree and of the commit-message check on the commits being pushed |

Run the whole gate on demand at any time:

```bash
./scripts/checks/run-all.sh            # everything, whole working tree
./scripts/checks/run-all.sh --staged   # only what is staged
```

### What CI will reject

Your pull request cannot be merged unless all of these are true:

- the PR **title** is a Conventional Commit (it becomes the squash-merge commit
  on `main`)
- every commit message in the branch is a Conventional Commit
- the **branch name** follows `<type>/<short-description>`
- no secret, private key, `.env` file, `package-lock.json` or `yarn.lock` is
  present anywhere in the branch
- no file larger than 1 MiB is committed
- `pnpm lint`, `pnpm type-check`, `pnpm format:check`, `pnpm test` and
  `pnpm build` all pass
- the branch contains **no merge commits** (we require a linear history)
- at least one approving review from a code owner (CODEOWNERS has a `*` entry,
  so every pull request has code owners)
- all review conversations are resolved
- the branch is up to date with `main`

### If a check blocks you and you think it is wrong

Do not bypass it. Fix it, or add a reviewed exception:

| Situation | Fix |
|:---|:---|
| A legitimate file is blocked | add it to `.github/allowed-files.txt` with a comment |
| A legitimate large file is blocked | add it to `.github/large-files.allowlist` with a justification |
| A secret pattern is a false positive | add the marker to `PLACEHOLDER_RE` in `scripts/checks/check-secrets.sh` and explain why |
| The PR is too large to review | split it into stacked PRs |

Exceptions in those two files show up in the pull request diff and are covered by
CODEOWNERS, so they are reviewed like any other change. Bypassing with
`--no-verify` only moves the failure into a review queue where somebody else has
to deal with it.

---

## 🚀 Submitting a Pull Request

Once you have verified your changes locally:

### 1. Rebase onto Upstream Main
```bash
git checkout main
git pull upstream main
git checkout <your-branch-name>
git rebase main
```

### 2. Push to Your Fork
```bash
git push origin <your-branch-name>
```

### 3. Open the Pull Request on GitHub
1. Navigate to [https://github.com/Open-Source-Software-Club/OSS_website](https://github.com/Open-Source-Software-Club/OSS_website).
2. You will see a banner prompting you to create a Pull Request from your branch. Click **Compare & pull request**.
3. Set base branch to `main`.
4. Give your PR a clear, descriptive title following Conventional Commits (e.g., `feat(events): add calendar export modal`).
5. Fill out the PR template, in particular:
   - **Description:** Concise description of changes.
   - **Related Issue:** `Fixes #<issue-number>` or `Closes #<issue-number>`.
   - **Screenshots / Recordings:** Mandatory for any visual or UI changes (both light and dark modes).
   - **How Has This Been Tested?** and the **Checklist:** tests, linting, and responsive design.
6. If you got the title wrong, just edit it — the `PR Conventions` check re-runs
   on its own. You do not need to push a new commit.

---

## 🔍 Review & Merge Process

- **Automated Checks:** GitHub Actions will run automated CI checks (Lint, Typecheck, Build, Format). If a check fails, inspect the action logs and push fixes to your branch.
- **Peer Review:** A club maintainer or technical lead will review your PR within **48 to 72 hours**.
- **Addressing Feedback:** If changes are requested:
  1. Make the requested edits locally on your feature branch.
  2. Commit your changes.
  3. Push to your fork: `git push origin <your-branch-name>`.
  4. The PR will automatically update!
- **Merge Requirements:**
  - At least **1 approving review** from a designated code owner / maintainer.
  - All CI workflows passing.
  - No merge conflicts with `main`.
  - Maintainers will squash and merge your PR into `main`.

---

## 🐣 First Contribution Walkthrough

If this is your first time contributing to an open-source project on GitHub, follow this quick-start walkthrough:

1. Look for issues labeled [`good first issue`](https://github.com/Open-Source-Software-Club/OSS_website/labels/good%20first%20issue).
2. Comment on the issue asking to be assigned.
3. Fork and clone the repository.
4. Create a branch: `git checkout -b docs/add-contributor-profile`.
5. Make your change (e.g., updating documentation, fixing a component style).
6. Run `pnpm typecheck && pnpm lint` to verify nothing is broken.
7. Commit your change: `git commit -m "docs(contributors): add my profile to README"`.
8. Push to your fork: `git push origin docs/add-contributor-profile`.
9. Submit the Pull Request on GitHub.
10. Celebrate! You are officially an open-source contributor! 🥳

---

## ⚠️ Common Pitfalls to Avoid

- **Submitting PRs directly to `main` branch:** Always branch out from an updated `main`. The `pre-push` hook refuses it, and branch protection refuses it.
- **Force-pushing a shared branch:** `release/**`, `hotfix/**`, `support/**` and the release tags are protected server-side. On your own feature branch a force-push is fine; on anything shared it silently rewrites history someone else may already be building on.
- **Re-tagging a release:** `Protect release tags` blocks deleting or moving a `v*` tag, and only accepts `v<major>.<minor>.<patch>[-prerelease]`. If a release is wrong, cut the next patch — do not move the tag.
- **Committing lockfiles from other tools:** Never commit `package-lock.json` or `yarn.lock`. Only `pnpm-lock.yaml` should exist.
- **Pushing `.env.local` or sensitive secrets:** Never commit API keys or private tokens. The pre-commit hook and the `Secret Scan` CI check both block this, and GitHub push protection blocks it before it even reaches the repository.
- **Creating giant monolithic PRs:** Keep PRs atomic and focused on a single issue. A PR that fixes three different bugs and redesigns two pages is difficult to review and will likely be rejected — and above 10,000 changed lines or 300 files it is rejected automatically by the PR Conventions check (it warns from 400 lines or 20 files).
- **Ignoring mobile responsiveness:** Always check your UI on mobile viewports (320px - 768px) and in both light and dark modes.

---

## 💬 Getting Help

Need assistance or have questions during the contribution process?

- **GitHub Discussions:** [Ask questions and discuss architectural ideas](https://github.com/Open-Source-Software-Club/OSS_website/discussions).
- **Club Discord Server:** [PLACEHOLDER: Club Discord Server Invitation Link, e.g., https://discord.gg/oss-svit].
- **Club Email:** [PLACEHOLDER: Club Email Address, e.g., oss@saividya.ac.in].
- **Campus Office Hours:** Visit the OSS Club desk during club hours at the Sai Vidya Institute of Technology campus.

Thank you for contributing to the SVIT Open Source Software Club! Let's build something remarkable together.
