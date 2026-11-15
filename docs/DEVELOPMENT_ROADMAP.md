# Development Roadmap

> §10 of the OSS Club Website PRD
> Related docs: [PRD](./PRD.md) · [ARCHITECTURE](./architecture.md) · [GITHUB_ISSUES](./GITHUB_ISSUES.md)

---

## Phases overview

| Phase | Objectives & deliverables | Depends | Complexity | Key risks |
|---|---|---|---|---|
| **0 Setup** | Next.js scaffold, pnpm, lint/type/test, CI, Vercel link, Supabase project + local CLI, `AGENTS.md`, templates, branch protection | — | S | Env/secret mishandling |
| **1 Design system + core** | Tokens, fonts, layout shell, nav, theme, primitives, Home (static data), About, Join/Contact UI | 0 | L | Design drift, a11y debt |
| **2 Content + CMS data** | Migrations for content tables, RLS+tests, Projects/Events/Learn/Team pages from DB, seed | 1 | M | Schema churn |
| **3 GitHub read integration** | GitHub App, token service, GraphQL sync, `gh_*`, webhooks, reconcile, repos on Projects | 2 | L | Rate limits, webhook reliability |
| **4 Contribution portal** | Issue list/filter/search/detail, PR feed, label sync, freshness UI | 3 | L | Label hygiene, search relevance |
| **5 Auth + admin** | Supabase GitHub login, roles, `/admin` CRUD, audit, interest requests, proposals→issue creation | 2,3,4 | XL | Authz bugs → mandatory tests |
| **6 Recognition + analytics** | Profiles, achievements, highlights, dashboard | 5 | M | Privacy/perceived fairness |
| **7 Hardening + launch** | E2E, a11y audit, perf, SEO, runbooks, load test sync, domain, launch checklist | all | M | Scope creep |

---

## Parallel tracks

Phases 1 and 3 can run **in parallel** (design vs integration tracks).

**Launch gate (MVP):** phases 0–4 + minimal admin from 5 (content CRUD). Interest requests/proposals may follow in v1.1.

---

## MVP acceptance criteria

- All P0 stories pass E2E
- Lighthouse budgets met (perf ≥ 90, a11y ≥ 95)
- RLS tests green
- No secrets in client bundle (CI grep + bundle check)
- axe zero critical violations
- Webhooks verified end-to-end on staging
- Runbook exists for:
  - Key rotation (GitHub App PEM, Supabase service role)
  - Webhook redelivery
  - Database restore
  - Sync failure recovery
