# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Branch protection rulesets**, split into four files under
  `.github/branch-protection/rulesets/` and applied by one script:
  `Protect main` (the merge gate), `Protect release branches`
  (`release/**`, `hotfix/**`, `support/**` — no force-push, no deletion,
  reviewed PRs), `Protect release tags` (immutable `v*` tags with semver-only
  names) and `Branch naming` (`<type>/<description>`, enforced by the server
  rather than only by the local hook). The former single `ruleset.json` is now
  `rulesets/protect-main.json`; `apply.sh` gained `--list` and `--file`.
- `optional/require-signed-commits.json`: the commit-signing rule, kept out of
  the default set because it would block a first-time contributor.
- `scripts/checks/check-rulesets.sh`: validates every ruleset payload against
  the rules GitHub accepts and fails the build when a required status check
  names a job no workflow emits — a typo that would otherwise make the branch
  permanently unmergeable, discoverable only at apply time. Runs in
  `Repository Hygiene` and in the local gate.
- `Workflow Security` (`workflow-security.yml`): a pinned `zizmor` audit that
  catches template injection, `pull_request_target` misuse, credential-stuffing
  of artifacts and unpinned actions in the pipeline itself.
- `Scorecard` (`scorecard.yml`): OpenSSF supply-chain posture published as SARIF
  to the Security tab.
- `Release Drafter` (`release-drafter.yml`): release notes assembled from the
  Conventional Commit titles that `PR Conventions` already enforces.
- `Deployment Smoke Test` (`smoke.yml`): verifies that the URL Vercel published
  actually renders, and reports the deployment's security headers.
- `scripts/checks/check-docs.sh`: documentation integrity — required documents
  exist, every relative link resolves, exactly one H1 per document.
- Shell linting of the pipeline itself (`bash -n` + `shellcheck`) in
  `Repository Hygiene`.
- Interactive calendar view for upcoming workshops and hackathons in `src/app/(main)/events`.
- Supabase Row Level Security (RLS) policies for student project submissions.
- GitHub API integration to automatically fetch star counts and contributor avatars for featured club repositories.
- Newsletter subscription form component with Supabase database persistence.
- Breadcrumbs component for nested documentation and blog pages.

### Changed
- Refactored `ProjectCard` component to support dynamic language color tags.
- Optimized hero section animations for low-power mobile devices.
- Hardened the CI/CD pipeline: GitHub Actions pinned to current Node 24 majors,
  `supabase/setup-cli@v1` and `actions/dependency-review-action@v4` (both moving
  branches) replaced with tags, and the Supabase CLI pinned in one place so CI
  and production migrations run the same binary.

### Fixed
- `protect-main.yml` raised a false incident on every push to `main`: it ran `git`
  commands without ever cloning the repository, and interpolated the commit
  subject into a `github-script` body.
- `pr-automation.yml` checked out the pull-request *head* inside a
  `pull_request_target` workflow, giving fork code a write token.
- `stale.yml` deleted merged branches with a read-only token, so every delete
  silently failed with 403.
- `labels-sync.yml` invoked a `label-sync` CLI that does not exist, and called
  `gh repo list` without the organisation token.
- `Verify` treated a *failing* `type-check` the same as a missing one and went
  green; the script that exists is now resolved before it runs.
- Six documents linked to `./ARCHITECTURE.md` (the file is
  `docs/architecture.md`), and the pull-request template linked to a
  `CONTRIBUTING.md` that resolves relative to `.github/`.
- Fixed layout shift (CLS) in navigation bar during dark/light theme hydration.
- Resolved mobile drawer menu failing to trap focus when opened.

---

## [0.1.0] - 2024-04-15

### Added
- **Core Architecture & Scaffolding:**
  - Initial project bootstrap using Next.js 14 App Router with React Server Components (RSC).
  - TypeScript 5 strict configuration (`strict: true`) and path aliases (`@/*`).
  - Tailwind CSS 3.4 configuration with custom SVIT brand colors and dark/light mode palette.
  - Integration of `shadcn/ui` primitives (Button, Card, Dialog, DropdownMenu, Avatar, Badge, Input, Form) powered by Radix UI.
  - Theme provider integration using `next-themes` with zero flash on load.
- **Pages & Routes:**
  - Responsive Homepage (`src/app/page.tsx`) with hero banner, club metrics counter, featured projects carousel, and core team teaser.
  - About Page (`src/app/(main)/about/page.tsx`) detailing club history, faculty coordinator message, mission, and leadership directory.
  - Events Directory (`src/app/(main)/events/page.tsx`) with category filtering (Hackathons, Workshops, Study Jams) and RSVP modal.
  - Projects Directory (`src/app/(main)/projects/page.tsx`) showcasing student open-source repositories with direct GitHub and live demo links.
  - Contributors Page (`src/app/(main)/contributors/page.tsx`) with automated GitHub contributor grid.
  - Custom branded 404 Not Found page (`src/app/not-found.tsx`).
- **Database & Authentication:**
  - Supabase client integration (`src/lib/supabase/client.ts` and `src/lib/supabase/server.ts`).
  - Initial PostgreSQL database migration schema for `events`, `projects`, and `club_members`.
  - Row Level Security (RLS) policies enabling public reads and authenticated admin writes.
- **Tooling & Developer Experience:**
  - ESLint ruleset tailored for Next.js App Router and TypeScript best practices.
  - Prettier configuration with `prettier-plugin-tailwindcss` for automated class sorting.
  - GitHub Actions CI workflow (`.github/workflows/ci.yml`) enforcing type checking, linting, formatting, and build verification on all pull requests.
  - Comprehensive `.env.example` file documenting all environment variable requirements.
- **Repository Documentation:**
  - Production-ready `README.md` with installation guides, architecture overview, and badges.
  - Comprehensive `CONTRIBUTING.md` including Git workflow, branch naming, Conventional Commits, and testing guidelines.
  - `CODE_OF_CONDUCT.md` based on Contributor Covenant v2.1.
  - Responsible disclosure `SECURITY.md` policy.
  - Open-source `LICENSE` (MIT).

[Unreleased]: https://github.com/Open-Source-Software-Club/OSS_website/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Open-Source-Software-Club/OSS_website/releases/tag/v0.1.0
