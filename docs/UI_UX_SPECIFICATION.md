# UI/UX Specification

> §7 of the OSS Club Website PRD
> Related docs: [PRD](./PRD.md) · [ARCHITECTURE](./architecture.md)

---

## 7.1 Brand & tokens

Logo green is **TBD** — sample the dominant non-neutral colour from the logo file (eyedropper on the mark, not the antialiased edge), then derive the scale with OKLCH. **Provisional** values below (replace after sampling):

```css
:root {            /* dark is default; light is first-class, not an afterthought */
  --bg:#0B0D0C; --surface:#121614; --surface-2:#181D1A; --border:#232A26; --border-strong:#33403A;
  --text:#E8EDEA; --text-muted:#93A09A; --text-faint:#5E6A64;
  --brand-300:#7CE3A6; --brand-400:#43D17E; --brand:#22C55E; --brand-600:#16A34A; --brand-ink:#052E16;
  --warn:#F5B342; --danger:#F26B6B; --info:#6EA8FE; --focus:#7CE3A6;
  --radius-sm:6px; --radius:10px; --radius-lg:16px;
  --shadow-1:0 1px 0 rgb(255 255 255/.04) inset,0 8px 24px -12px rgb(0 0 0/.6);
  --space:4px;  /* scale 4,8,12,16,24,32,48,64,96,128 */
}
[data-theme=light]{
  --bg:#F7F8F6; --surface:#FFFFFF; --surface-2:#EFF2EF; --border:#DCE2DD;
  --text:#101412; --text-muted:#4F5C55; --brand:#15803D; --brand-ink:#FFFFFF; --focus:#15803D;
}
```

**Rules:**
- Green only for primary action, focus, live/"available" signals, and key data marks — **≤ 10% of any viewport**
- Verify contrast: body text ≥ 4.5:1, UI ≥ 3:1 in both themes (use a CI contrast check on tokens)

**Typography:**
- Display — *Instrument Serif* (editorial headlines, sparse, large)
- UI/body — *Geist Sans*
- Code/data/labels — *Geist Mono*
- Scale (rem): 0.75/0.875/1/1.125/1.5/2/3/4.5/7 with `clamp()`
- Body 16–17px / 1.6; mono caps micro-labels 12px tracking .08em

**Signature motifs (what makes it ours, not SaaS-template):**

1. **Git-graph line** — a thin vertical branch/merge line runs down the homepage left gutter connecting sections as commits (SVG, scroll-linked, ends in a "merge" at the CTA)
2. **Mono "metadata strips"** — each section starts with a `§ 03 — PROJECTS` style label and a live data chip (e.g. `42 open issues · synced 2m ago` — real values only)
3. **Index-not-cards** — projects/events presented as editorial table-like rows with hover reveal, not uniform card grids; cards reserved for issues
4. **Diff-style highlights** — pull-quote and emphasis use `+`/`-` gutter styling sparingly

**Avoid:** heavy glass, mesh gradients, stock illustrations, parallax overuse.

---

## 7.2 Components (spec essentials)

- **Button:** primary (brand bg, ink text), secondary (surface-2 + border), ghost, link-with-arrow; 40px height (44px touch on mobile); hover: 120 ms bg shift + arrow translate 2px; focus: 2px `--focus` ring offset 2px; loading: spinner replaces icon, width locked; disabled: 50% + `aria-disabled`.
- **Issue card:** repo·#number (mono) / title (2 lines max) / label chips (difficulty coloured dot + text, never colour-only) / skills / age / assignee avatar or "Unassigned" / actions [View on GitHub ↗] [Interest]. Hover: border-strong + 1px lift. Skeleton: same box, 3 shimmer bars.
- **Filter bar:** sticky, URL-synced; difficulty segmented control; multi-select Combobox for language/area/skill; search input (`/` focuses); "Clear all"; result count `aria-live=polite`.
- **Data states (every data view):** *Loading* skeleton matching layout (no spinners for lists) · *Empty* mono title + one-line explanation + one action · *Error* plain-language message, retry, "Open on GitHub" fallback · *Stale* subtle amber "Last synced 3 h ago" chip.
- **Motion:** durations 120/200/400 ms; ease `cubic-bezier(.2,.8,.2,1)`; page reveal = opacity+8px translate, once, IntersectionObserver; hero graph animation pauses off-screen; `prefers-reduced-motion` → all transforms/autoplay removed, content immediately visible.
- **Breakpoints:** 360 (min), 640, 768, 1024, 1280, 1536; content max 1200 (prose 68ch). Verified at 360px: no horizontal scroll.
- **A11y (WCAG 2.2 AA):** skip link; landmarks; visible focus (2.4.11 not obscured by sticky header → `scroll-margin-top`); targets ≥ 24px (we use 44); labelled forms with inline errors tied by `aria-describedby`; dialogs trap focus & restore; no colour-only status; `axe` in CI + manual NVDA/VoiceOver pass pre-launch.

---

## 7.3 Homepage — implementable spec

Single column rhythm with an asymmetric 12-col grid; git-graph line sits in col 1 (hidden < 768, replaced by small node markers).

### 1. Hero (100svh, min 640)

**Left (cols 1–7):** mono eyebrow `OSS CLUB · SAI VIDYA INSTITUTE OF TECHNOLOGY`; H1 in Instrument Serif 7rem→3rem: *placeholder copy* "Read the source. Then write the next commit."; sub (1–2 lines) explaining club; CTAs [Make your first contribution →] (→ `/contribute?difficulty=beginner`) and [See projects].

**Right (cols 8–12):** live terminal-style panel rendering real cache data — latest 5 events: `opened  #214 repo-name — Add dark-mode toggle`, `merged  PR #88 by @login`; types in line-by-line once; static fallback for reduced motion/no JS; if data empty, shows onboarding lines instead (no fake data). Bottom strip: sync freshness + scroll cue.

### 2. Manifesto (editorial)

Cols 2–8 large serif paragraph (what open source is + why the club exists; copy TBD by club), cols 9–12 sidebar with three mono "principles" (placeholders). Words highlight on scroll (opacity 0.4→1) unless reduced motion.

### 3. Right now (live)

Header `§ 02 — RIGHT NOW`. Three columns: *Open beginner issues* (top 4 issue cards), *Recent merges* (4 rows), *Next event* (single large row w/ date block). All server-rendered, ISR 60 s. Empty state per column.

### 4. Projects index

Rows (not cards): `01  ProjectName ········ TS · Next.js ········ Active ↗`; hover expands one-line problem statement + maintainer avatars; featured project gets a larger row with repo stats. Max 6 + "All projects".

### 5. Your first PR in 5 steps

Vertical branch visual: nodes `fork → clone → branch → commit → pull request` each with 1-line explainer & link to learning track; the line "merges" into main at the end.

### 6. Events

Horizontal timeline on desktop (snap-scroll), vertical stack on mobile; next event highlighted; past events collapsed link.

### 7. Contributors (opt-in only)

Avatar wall with GitHub handle on hover; hidden entirely if no opted-in profiles.

### 8. Join CTA

Full-bleed dark surface, giant serif line, one primary button, community link(s) TBD.

### 9. Footer

Logo, sitemap columns, GitHub org link, theme toggle, "Built in the open — view source" link to repo, copyright.

**Stats rule:** only show numbers pulled from data (repos, open issues, merged PRs). Member counts etc. appear only after club provides verified values.

---

## 7.4 Other pages (layout summary — each also needs loading/empty/error per §7.2)

- **/projects:** left filter rail (status, language), asymmetric index list; detail page = editorial header (name, status chip, stack), problem/objectives prose, maintainers, live issues + PRs tabs, docs links, "Contribute" sticky aside.
- **/contribute:** top = intro + "how it works" 3-step strip; sticky filter bar; results grid (2 col desktop / 1 mobile, cursor pagination "Load more" + URL page param for SEO-less list); right rail "Your progress" (signed-in: requests & states; signed-out: sign-in prompt). Issue detail = cached markdown preview (sanitised), skills, repo links, CTA hierarchy: **Open on GitHub** (primary) → **Interest** (secondary, signed-in).
- **/events:** featured next event, then list grouped Upcoming/Past; detail with registration button (external link), gallery (lazy, `next/image`, captions).
- **/learn:** tracks as numbered chapters; resource page = markdown with TOC, reading time, prev/next, "mark complete" (P2, local only until accounts).
- **/team:** groups with role-labelled rows; avatar + roles + GitHub link; only `visible=true` entries.
- **/join:** why/expectations/process (3 steps), embedded form (name, email, branch/year, GitHub username, interests) → table `join_applications` (add; RLS: insert anon with captcha, select admin) + confirmation state; community links TBD.
- **/contact + sponsors:** form with honeypot + Turnstile; sponsor tiers only if club defines them (TBD).
