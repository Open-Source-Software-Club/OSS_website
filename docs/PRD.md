# OSS Club Website & Contribution Platform — Product Requirements Document

> **Document owner:** Open Source Software Club, Sai Vidya Institute of Technology, Bengaluru
> **Repository:** [Open-Source-Software-Club/OSS_website](https://github.com/Open-Source-Software-Club/OSS_website)
> **Related docs:** [ARCHITECTURE](./architecture.md) · [DATABASE_SCHEMA](./DATABASE_SCHEMA.md) · [GITHUB_INTEGRATION](./GITHUB_INTEGRATION.md) · [UI_UX_SPECIFICATION](./UI_UX_SPECIFICATION.md) · [DEVELOPMENT_ROADMAP](./DEVELOPMENT_ROADMAP.md) · [GITHUB_WORKFLOW](./GITHUB_WORKFLOW.md) · [GITHUB_ISSUES](./GITHUB_ISSUES.md)

---

## 0. Status, verified facts, assumptions

### 0.1 Verified (inspected)

| Item | Finding |
|---|---|
| Repo `Open-Source-Software-Club/OSS_website` | **Public, greenfield build.** No framework, no files to migrate. |
| Repo description | "Official website of the OSS Club at **Sai Vidya Institute of Technology**" — confirms institution. |
| Logo | Club logo available at `public/assets/brand/logo.png`. Brand green is **provisional** — sample the dominant non-neutral colour from the logo file, then derive the scale with OKLCH. |

### 0.2 TBD — needs club confirmation (do NOT invent)

Faculty coordinator/affiliation text · member count · achievements/history/milestones · sponsors · contact email/social handles · Discord/WhatsApp link · exact logo green HEX · domain name · who are the Super Admins · existing org repos · college branding rules.

### 0.3 Section → file map

| Section | File |
|---|---|
| §1–3 (Product, Requirements, IA) | `PRD.md` (this file) |
| §4 (System architecture) | `ARCHITECTURE.md` |
| §5 (Database) | `DATABASE_SCHEMA.md` |
| §6 (GitHub integration) | `GITHUB_INTEGRATION.md` |
| §7 (UI/UX specification) | `UI_UX_SPECIFICATION.md` |
| §8–9 (Security, Analytics) | `PRD.md` (this file) |
| §10 (Roadmap) | `DEVELOPMENT_ROADMAP.md` |
| §11 (GitHub workflow) | `GITHUB_WORKFLOW.md` |
| §12 (Starter backlog) | `GITHUB_ISSUES.md` |

---

## 1. Product summary

**One-liner:** A premium, dark, editorial developer-community site whose centrepiece is a GitHub-powered contribution portal — GitHub stays the source of truth for code; the site adds discovery, community, events, learning, and admin.

**Principles**

1. GitHub owns repos/issues/PRs/assignments. We never build a parallel tracker.
2. Supabase stores only what GitHub can't: content, people, workflow state, audit.
3. One Next.js app. No microservices. No queues beyond a table.
4. Ship the MVP (website + read-only portal) before write-back features.

### 1.1 Personas

Visitor · Beginner student · Registered member · Project maintainer · Club admin · Super admin · Sponsor/mentor (read-only audience).

### 1.2 MVP vs later

| Tier | Scope |
|---|---|
| **MVP (P0)** | Design system; Home, About, Projects (+detail), Events, Learning, Team, Join, Contact; org repo + issue discovery (read-only, filters, search); GitHub login; admin CRUD for projects/events/resources/announcements/team; CI/CD; SEO/a11y baseline |
| **P1** | Contribution requests ("express interest"); PR feed; issue proposals → admin → GitHub issue; webhooks; roles UI; audit log UI |
| **P2** | Contributor profiles, achievements, monthly highlights, privacy-first analytics dashboard, event galleries |
| **P3 (future)** | Mentorship matching, GSoC tracker, newsletter, i18n, in-site notifications, PWA |

---

## 2. Functional requirements (condensed user stories)

Format: **ID · Story · Priority · Depends · Acceptance (G/W/T) · Edge/error**

| ID | Story | P | Depends |
|---|---|---|---|
| WEB-01 | As a visitor, I want the homepage to explain the club in <10s so I know what it is and how to join | P0 | DS-01 |
| PRJ-01 | As a visitor, I want to browse/filter projects by status & language | P0 | GH-01 |
| PRJ-02 | As a visitor, I want a project detail page with README summary, maintainers, issues, PRs | P0 | PRJ-01, GH-02 |
| CON-01 | As a beginner, I want to see only beginner-friendly open issues | P0 | GH-02 |
| CON-02 | As a member, I want to express interest in an issue | P1 | AUTH-01, CON-01 |
| CON-03 | As a maintainer, I want to approve interest and be sent to GitHub to assign | P1 | CON-02 |
| CON-04 | As a member, I want to propose an issue | P1 | AUTH-01 |
| CON-05 | As an admin, I want to approve a proposal and create the GitHub issue | P1 | CON-04, GH-05 |
| EVT-01 | As a visitor, I want upcoming/past events with registration links | P0 | — |
| LRN-01 | As a beginner, I want tracks of ordered resources | P0 | — |
| AUTH-01 | As a student, I want to sign in with GitHub | P0 | — |
| ADM-01 | As an admin, I want CRUD on content with draft/publish | P0 | AUTH-01, RBAC |
| REC-01 | As a contributor, I want opt-in public profile with merged-PR history | P2 | GH-04 |

### Fully worked examples (use as template for the rest)

#### CON-01 — Filter beginner issues (P0)

- *G* issue cache has 40 open issues, 12 labelled `good first issue` · *W* user toggles "Beginner friendly" · *T* list shows exactly those 12, URL becomes `?difficulty=beginner`, count badge reads 12, back button restores previous state.
- *G* no matches · *T* empty state: "No beginner issues right now" + CTA "Propose an issue" (members) / "Browse all issues".
- *Edge:* issue closed on GitHub between sync and click → card shows "Closed on GitHub" after webhook; stale cards ≤ 60 s (webhook) / ≤ 15 min (fallback).
- *Error:* cache read fails → error panel with retry; page remains navigable.

#### CON-02 — Express interest (P1)

- *G* signed-in member, issue unassigned, no active request by this user · *W* clicks "I'd like to work on this" · *T* row in `contribution_requests` status `requested`, button becomes "Interest sent", maintainer notified in admin queue. **UI copy must say "Interest" — never "Assigned".**
- *Edge:* issue already assigned → button disabled with tooltip. Max 3 concurrent active requests/user. Duplicate request → 409 handled idempotently.
- *Error:* GitHub down → request still stored (workflow state is ours); unaffected.

#### CON-05 — Approve proposal (P1)

- *G* admin on a `pending` proposal · *W* approves with final labels · *T* server creates GitHub issue via App token, stores `github_issue_number`, status `created`, audit row written, proposer notified.
- *Error:* GitHub 403/5xx → status `approval_failed`, retry button, no duplicate on retry (idempotency key stored before call).

---

## 3. Information architecture

```
/                       Home
/about
/projects               index (filter/search)
/projects/[slug]        detail
/contribute             portal (issues, filters, my progress)
/contribute/issues/[repo]/[number]   issue detail (cached preview → GitHub)
/contribute/propose     (auth)
/pulls                  PR feed
/events  /events/[slug]
/learn   /learn/[track]/[slug]
/team    /team/[handle]
/community              contributor wall (opt-in)
/join
/contact  (+ /sponsors)
/dashboard              member area (my requests, proposals, profile, privacy)
/admin/*                role-gated
/login  /auth/callback
/api/*
/sitemap.xml /robots.txt /opengraph-image
```

### Navigation

**Desktop nav:** Logo · Projects · Contribute · Events · Learn · Team · About — right: theme toggle · GitHub star · Join (primary) / avatar menu.

**Mobile nav:** top bar (logo + menu button) → full-screen sheet, focus-trapped, 5 primary links + Join pinned bottom; `/contribute` also gets a sticky bottom filter button.

---

## 8. Security, performance, SEO

### Security checklist

- Secrets only in env; `lib/env.ts` Zod-validates at boot; `server-only` on GitHub/service-role modules; GitHub secret scanning + push protection on.
- AuthZ at 3 layers: middleware (route gating) → server `requireRole()` → RLS.
- Zod on every input; markdown rendered via `react-markdown` + `rehype-sanitize` (no raw HTML); CSP header (nonce-based), `X-Frame-Options`/`frame-ancestors none`, HSTS, `Referrer-Policy`, `Permissions-Policy`.
- CSRF: Server Actions same-origin protections + SameSite=Lax cookies; Route Handlers that mutate require `Origin` check + auth.
- Rate limit (Upstash Redis or Postgres counter): forms 5/h/IP, requests 20/h/user, proposals 3 pending/user. Turnstile on public forms.
- Webhook HMAC + delivery dedupe; cron bearer secret; admin actions all write `audit_logs`.
- Dependabot + `pnpm audit` in CI; CodeQL.
- Privacy: no third-party trackers; IP stored only as salted hash for rate limit, 24 h TTL.

### Performance budgets

- LCP < 2.5 s, INP < 200 ms, CLS < 0.1 on mid-range mobile
- JS ≤ 170 KB gz on marketing routes
- Fonts subset + `display:swap`
- Images via `next/image` (AVIF/WebP, explicit sizes)
- Hero animation SVG/CSS (no WebGL in MVP)
- Lighthouse CI gate (perf ≥ 90, a11y ≥ 95)

### SEO

- `generateMetadata` per route; dynamic OG images (`opengraph-image.tsx`)
- `sitemap.ts` including projects/events/resources/team
- `robots.ts` (disallow `/admin`, `/dashboard`, `/api`)
- JSON-LD: `Organization`, `Event`, `Article`/`LearningResource`
- Canonical URLs

---

## 9. Recognition & analytics

### Recognition (P2, opt-in)

Verified source = GitHub **merged PRs** into org repos, authored by a linked account, linked to an issue or reviewed by someone other than the author (self-merged PRs don't count). Not counted: commit counts, trivial whitespace-only PRs (<3 changed lines in non-doc files, flagged for maintainer override), closed-unmerged PRs.

**Achievements:** `first-pr-merged`, `docs-contributor` (≥1 merged PR labelled `area: docs`), `reviewer` (≥3 approving reviews on others' PRs), `maintainer`, `monthly-highlight` (admin-curated, not automatic). No ranked all-time leaderboard in MVP; if added, "this month — merged PRs" only, opt-in, with admin ability to hide. Each award stores `evidence` (PR URLs) for auditability and is recomputable from GitHub.

### Analytics (privacy-first)

Use cookieless, aggregate-only (Vercel Analytics or self-hosted Plausible/Umami — decision needed) plus first-party `analytics_events` for custom counts (no user/IP).

**Metrics:**
- Unique visitors (tool)
- Join-form submissions (table count)
- Issue-click-outs (`outbound_issue` event)
- Interest requests (table)
- First-time contributors (profiles whose first merged PR is in period)
- PRs opened/merged (`gh_pulls`)
- Active projects (≥1 PR/issue activity in 30 d)
- Event registration clicks (`outbound_register`)
- Resource views (aggregate)

Show on `/admin` overview.
