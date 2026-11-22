# Maintainers

The people who review, merge and look after this repository, and the parts of
it each group is responsible for. Review routing is defined by
[`.github/CODEOWNERS`](.github/CODEOWNERS); this page explains it in words.
How someone joins these groups is described in [GOVERNANCE.md](GOVERNANCE.md).

## Technical leads — `@Open-Source-Software-Club/technical-leads`

Own the parts of the repository where a mistake becomes a security or
availability problem rather than a broken page:

- CI/CD and repository automation: `.github/`, `scripts/`, `.githooks/`
- Branch protection rulesets: `.github/branch-protection/`
- Security-sensitive application code: `src/lib/github/`, `src/lib/rbac/`,
  `src/lib/env/`, `src/lib/supabase/`, `src/middleware.ts`,
  `src/app/api/webhooks/`, `src/app/api/cron/`
- The database: `supabase/migrations/`, `supabase/tests/`, `supabase/seed.sql`
- The security policy: [SECURITY.md](SECURITY.md) — **security reports go to
  them first**

| GitHub | |
|---|---|
| [@NizzyStark](https://github.com/NizzyStark) | Technical lead |
| [@Yashwanth-202011](https://github.com/Yashwanth-202011) | Technical lead |
| [@OssSvit](https://github.com/OssSvit) | The club's shared organisation account; used for administration, not for day-to-day review |

## Core team — `@Open-Source-Software-Club/core-team`

Review everything not owned more specifically above: the application, the
design system (`src/styles/`, `src/components/`), content, issue and pull
request templates, and documentation.

| GitHub | Also responsible for |
|---|---|
| [@Hiteshsai007](https://github.com/Hiteshsai007) | Club leadership documents (see below) |
| [@Tarun4201](https://github.com/Tarun4201) | Club leadership documents |
| [@harshab054](https://github.com/harshab054) | Club leadership documents |
| [@Rakshitha-JK7](https://github.com/Rakshitha-JK7) | |
| [@Shreekar-cloud](https://github.com/Shreekar-cloud) | |
| [@charangowdamd-cmd](https://github.com/charangowdamd-cmd) | |
| [@NizzyStark](https://github.com/NizzyStark) | Technical lead (above) |
| [@Yashwanth-202011](https://github.com/Yashwanth-202011) | Technical lead (above) |
| [@OssSvit](https://github.com/OssSvit) | The club's shared organisation account |

## Club leadership documents

The Code of Conduct, LICENSE, CHANGELOG, README, brand assets
(`public/assets/brand/`) and the admin area (`src/app/admin/`) are owned by
@Hiteshsai007, @Tarun4201 and @harshab054 by name, because no team matches
that group.

## Getting a review

You do not need to pick a reviewer: GitHub requests the owning team of the
files you changed. If a pull request has had no review for **three working
days**, mention the owning team in a comment (for example
`@Open-Source-Software-Club/technical-leads`) — that is expected, not rude.

Once a pull request is approved and green, any maintainer can press
**Merge when ready**: it joins the merge queue, which tests it on top of the
latest `main` and merges it. Nobody has to update the branch or re-approve.

### For team maintainers: turn on review assignment

So that a review request reaches one or two people rather than the whole team,
a maintainer of each team turns on **Code review assignment** once
(Organisation → Teams → the team → Settings → Code review): enable *auto
assignment*, set *How many team members should be assigned* to 1 (2 for
`technical-leads`), choose *Load balance*, and tick *Don't notify the entire
team*. This is a setting of the team, not of the repository, so no pull request
can change it.

## Keeping this page true

This file, CODEOWNERS and the team memberships in the organisation settings must
agree. A change to one is a change to all three, in the same pull request where
possible.
