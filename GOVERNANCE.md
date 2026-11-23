# Governance

How decisions are made in this repository, who can make them, and how people
take on more responsibility. Who currently holds each role is listed in
[MAINTAINERS.md](MAINTAINERS.md).

This is a student club's project: people join every semester and graduate
every year. Most of what follows exists so the project keeps working when they
do.

## Roles

| Role | Who | Can |
|---|---|---|
| **Contributor** | Anyone who opens an issue or pull request | Claim an open, triaged issue (`/assign`), open pull requests, review others' pull requests (a non-binding review is always welcome) |
| **Triager** | Contributors trusted to sort incoming work | Label, assign and close issues; request changes on pull requests |
| **Maintainer** | Members of `@Open-Source-Software-Club/core-team` | Approve and merge pull requests in the areas CODEOWNERS gives them |
| **Technical lead** | Members of `@Open-Source-Software-Club/technical-leads` | Everything a maintainer can, plus approve changes to CI/CD, security-sensitive code, the database and the branch protection rulesets; handle security reports |

Approvals only count where CODEOWNERS names you, and nobody approves their own
pull request.

## How decisions are made

- **Day to day — in the pull request.** If the code owners approve and the
  checks pass, the change is accepted. Silence is not approval: a pull request
  needs an explicit review.
- **Bigger changes — in an issue first.** New pages or features, new
  dependencies, changes to the architecture in [docs/architecture.md](docs/architecture.md),
  the database schema, the label taxonomy or the CI/CD pipeline start as an
  issue, so the approach is agreed before anyone writes code.
- **Disagreements** are settled by the technical leads for technical
  questions and by the core team for everything else. If they cannot agree, the
  majority of the core team decides.
- **This document and the branch protection rulesets** change only through a
  pull request approved by a technical lead and at least one other maintainer.

## Response targets

Targets, not guarantees — this is volunteer work around exams. They exist so
contributors know what to expect and when to follow up.

| Event | First response within |
|---|---|
| A new issue is triaged (labelled, or closed with a reason) | 3 working days |
| A pull request gets its first review | 3 working days |
| A security report is acknowledged | 48 hours (see [SECURITY.md](SECURITY.md)) |

If a target is missed, mention the owning team on the issue or pull request.

## Becoming a maintainer

Responsibility follows sustained contribution. A contributor becomes a
**triager** after a few merged pull requests and helpful reviews, and a
**maintainer** after roughly a semester of both, when a current maintainer
nominates them in an issue and the technical leads agree. The change is made in
one pull request that updates [MAINTAINERS.md](MAINTAINERS.md),
[`.github/CODEOWNERS`](.github/CODEOWNERS) and the team membership.

## Semester handover

At the start of every semester, the technical leads open an issue titled
**"Maintainer handover — <semester>"** and use it to:

1. confirm who is still active, and move graduating or inactive maintainers to
   the **Emeritus** list below (their history stays; their review duties end);
2. make sure every area in CODEOWNERS still has at least **two** active owners,
   so no change can be blocked by one person's exams or absence;
3. check that the organisation's admins and the repository's secrets
   (`SUPABASE_*`, `CRON_SECRET`, deployment credentials) are held by people who
   are still in the club, rotating any held by someone who is leaving.

## Emeritus

Former maintainers who have stepped back. Thank you.

*None yet.*

## Code of Conduct

Everyone taking part in this project follows the
[Code of Conduct](CODE_OF_CONDUCT.md). Maintainers are responsible for
enforcing it, as described there.
