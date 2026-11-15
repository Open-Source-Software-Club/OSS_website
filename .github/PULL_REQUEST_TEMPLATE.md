<!--
===============================================================================
 PULL REQUEST TEMPLATE — Open Source Software Club Website

 Your PR title becomes the squash-merge commit on `main`, so it MUST follow
 Conventional Commits:  <type>(<scope>): <subject>
 e.g.  feat(events): add RSVP button and counter
       fix(auth): resolve redirect loop after login

 Before you open this PR, run the same gate CI will run:
   ./scripts/checks/run-all.sh          (or: pnpm check, once package.json exists)

 CI will reject this pull request if any of the following are true:
   * the title is not a Conventional Commit
   * the branch name does not follow <type>/<short-description>
   * a commit message is not a Conventional Commit
   * a secret, private key, .env file or foreign lockfile is present
   * lint, types, formatting, tests or the build fail
   * the PR contains merge commits (we require a linear history)
   * the PR touches CODEOWNERS-protected paths without the required approvals

 Fill in every section. An empty description is the single most common reason
 a review is delayed.
===============================================================================
-->

## Description

<!-- A brief summary of what changed and, more importantly, WHY. -->



## Related Issue

<!-- Every PR should link the issue it resolves. Example: Closes #42 -->
Closes #

## Type of Change

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📝 Documentation update (changes to README, docs, or inline code comments)
- [ ] 🎨 Style / UI enhancement (styling, Tailwind CSS, shadcn/ui updates, formatting, etc.)
- [ ] ♻️ Code refactor (refactoring code without changing functionality or external behavior)
- [ ] ⚡ Performance improvement (code optimization, asset compression, bundle size reduction)
- [ ] 🧪 Test addition or update (adding missing tests or updating existing tests)
- [ ] 🔧 CI / tooling change (workflows, hooks, configuration)

## Changes Made

<!-- Detail the specific technical and functional changes. Include file paths
     for anything non-obvious. -->

-


## Screenshots / Recordings

<!-- Mandatory for any visual or UI change, in BOTH light and dark mode. -->

| Before | After |
| :---: | :---: |
| _Not applicable_ | _Add screenshot or recording here_ |

## How Has This Been Tested?

- **Test environment:** Node.js 22 LTS, pnpm 9
- **Automated tests run:** `pnpm lint`, `pnpm type-check`, `pnpm format:check`, `pnpm test`, `pnpm build`
- **Local gate:** `./scripts/checks/run-all.sh` passes
- **Manual testing steps:**
  1.
  2.
- **Browsers / viewports tested:**
  - [ ] Chrome (Desktop)
  - [ ] Firefox (Desktop)
  - [ ] Safari (Desktop / iOS)
  - [ ] Edge (Desktop)
  - [ ] Mobile viewport (360px minimum, no horizontal scroll)

## Database Changes

<!-- If this PR adds or edits a migration, say so here. Migrations are NEVER
     applied automatically; they go through the manual-approval workflow. -->

- [ ] No database changes
- [ ] Migration added (`supabase/migrations/`)
- [ ] RLS policy added or changed (pgTAP test included?)

## Checklist

- [ ] My code follows the project's coding conventions in [CONTRIBUTING.md](../CONTRIBUTING.md)
- [ ] I have performed a self-review of my own diff
- [ ] I have added comments where the code is not self-explanatory
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix or feature works
- [ ] New and existing tests pass locally
- [ ] I have run `./scripts/checks/run-all.sh` and it passes
- [ ] I have not committed any secret, key, `.env` file or lockfile from another package manager
- [ ] I have not committed build output, `node_modules`, editor droppings or large binaries
- [ ] Any dependent changes have been merged and are listed in "Related Issue"
- [ ] I have checked my code for accessibility (keyboard, focus, contrast, screen reader)
- [ ] I have checked my UI in both light and dark mode
- [ ] My branch is rebased onto the latest `main` and contains no merge commits

## Breaking Changes

<!-- Does this PR introduce breaking changes? Describe the impact and the
     migration path for users and developers. -->

- [ ] No breaking changes
- [ ] Yes (explain below):

## Additional Notes

<!-- Deployment notes, follow-up tasks, anything a reviewer should know that is
     not visible in the diff. -->
