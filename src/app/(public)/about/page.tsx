import type { Metadata } from "next";
import Link from "next/link";
import { ArrowUpRight, BookOpen, Code2, Globe, GraduationCap, Users } from "lucide-react";

export async function generateMetadata(): Promise<Metadata> {
  const description =
    "Learn about OSS Club, the Open Source Software Club at Sai Vidya Institute of Technology " +
    "(SVIT) -- our mission, values, history, and faculty leadership.";

  return {
    title: "About -- OSS Club SVIT",
    description,
    openGraph: {
      title: "About -- OSS Club SVIT",
      description,
      url: "/about",
      siteName: "OSS Club SVIT",
      type: "website",
    },
  };
}

export default function AboutPage() {
  return (
    <main className="min-h-screen bg-[var(--bg,#0B0D0C)] text-[var(--text,#E8EDEA)]">
      <div className="mx-auto max-w-6xl px-4 py-12 sm:px-6 md:py-20 lg:px-8">
        {/* ============================================================== */}
        {/* Hero Section                                                   */}
        {/* ============================================================== */}
        <section
          aria-labelledby="about-hero-heading"
          className="border-b border-[var(--border,#232A26)] pb-16 md:pb-24"
        >
          <div
            className={
              "flex items-center gap-2 font-mono text-xs uppercase tracking-widest " +
              "text-[var(--brand,#22C55E)]"
            }
          >
            <span
              className="inline-block h-2 w-2 rounded-full bg-[var(--brand,#22C55E)]"
              aria-hidden="true"
            />
            <span>&sect; 01 &mdash; ABOUT US</span>
          </div>

          <h1
            id="about-hero-heading"
            className={
              "mt-6 font-serif text-4xl sm:text-5xl md:text-6xl lg:text-7xl " +
              "tracking-tight text-[var(--text,#E8EDEA)]"
            }
          >
            {/* TODO: Club to provide official hero headline */}
            Read the source. Then write the next commit.
          </h1>

          <p
            className={
              "mt-6 max-w-3xl font-sans text-lg leading-relaxed md:text-xl " +
              "text-[var(--text-muted,#93A09A)]"
            }
          >
            {/* TODO: Club to provide official club mission subtitle */}
            The Open Source Software Club at Sai Vidya Institute of Technology is a student-led
            engineering collective. We empower developers to build public goods, master
            collaborative Git workflows, and make meaningful contributions to real-world open-source
            software.
          </p>
        </section>

        {/* ============================================================== */}
        {/* Pillars / What We Do Section                                   */}
        {/* ============================================================== */}
        <section
          aria-labelledby="pillars-heading"
          className="border-b border-[var(--border,#232A26)] py-16 md:py-24"
        >
          <div className="font-mono text-xs uppercase tracking-widest text-[var(--text-faint,#5E6A64)]">
            &sect; 02 &mdash; WHAT WE DO &middot; CORE PILLARS
          </div>

          <h2
            id="pillars-heading"
            className="mt-4 font-serif text-3xl text-[var(--text,#E8EDEA)] sm:text-4xl md:text-5xl"
          >
            Values driving our craftsmanship
          </h2>

          <div className="mt-12 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {/* Pillar 1: Production Open Source */}
            <article className="group rounded-[var(--radius,10px)] border border-[var(--border,#232A26)] bg-[var(--surface,#121614)] p-6 transition-colors hover:border-[var(--border-strong,#33403A)]">
              <div
                className={
                  "flex h-10 w-10 items-center justify-center rounded-[var(--radius-sm,6px)] " +
                  "bg-[var(--surface-2,#181D1A)] text-[var(--brand,#22C55E)]"
                }
              >
                <Code2 className="h-5 w-5" aria-hidden="true" />
              </div>
              <h3 className="mt-4 font-sans text-lg font-semibold text-[var(--text,#E8EDEA)]">
                Production Code
              </h3>
              <p className="mt-2 font-sans text-sm leading-relaxed text-[var(--text-muted,#93A09A)]">
                {/* TODO: Club to provide pillar description */}
                We move beyond toy projects. Members architect real tools, maintain packages, and
                push pull requests to production ecosystems.
              </p>
            </article>

            {/* Pillar 2: Inclusive Community */}
            <article className="group rounded-[var(--radius,10px)] border border-[var(--border,#232A26)] bg-[var(--surface,#121614)] p-6 transition-colors hover:border-[var(--border-strong,#33403A)]">
              <div
                className={
                  "flex h-10 w-10 items-center justify-center rounded-[var(--radius-sm,6px)] " +
                  "bg-[var(--surface-2,#181D1A)] text-[var(--brand,#22C55E)]"
                }
              >
                <Users className="h-5 w-5" aria-hidden="true" />
              </div>
              <h3 className="mt-4 font-sans text-lg font-semibold text-[var(--text,#E8EDEA)]">
                Open Community
              </h3>
              <p className="mt-2 font-sans text-sm leading-relaxed text-[var(--text-muted,#93A09A)]">
                {/* TODO: Club to provide pillar description */}A welcoming, mentorship-driven home
                for every student &mdash; from first-year git beginners to seasoned maintainers.
              </p>
            </article>

            {/* Pillar 3: Hands-on Learning */}
            <article className="group rounded-[var(--radius,10px)] border border-[var(--border,#232A26)] bg-[var(--surface,#121614)] p-6 transition-colors hover:border-[var(--border-strong,#33403A)]">
              <div
                className={
                  "flex h-10 w-10 items-center justify-center rounded-[var(--radius-sm,6px)] " +
                  "bg-[var(--surface-2,#181D1A)] text-[var(--brand,#22C55E)]"
                }
              >
                <BookOpen className="h-5 w-5" aria-hidden="true" />
              </div>
              <h3 className="mt-4 font-sans text-lg font-semibold text-[var(--text,#E8EDEA)]">
                Learn in Public
              </h3>
              <p className="mt-2 font-sans text-sm leading-relaxed text-[var(--text-muted,#93A09A)]">
                {/* TODO: Club to provide pillar description */}
                Peer code reviews, technical workshops, and real-time pair programming designed to
                build genuine engineering instincts.
              </p>
            </article>

            {/* Pillar 4: Global Impact */}
            <article className="group rounded-[var(--radius,10px)] border border-[var(--border,#232A26)] bg-[var(--surface,#121614)] p-6 transition-colors hover:border-[var(--border-strong,#33403A)]">
              <div
                className={
                  "flex h-10 w-10 items-center justify-center rounded-[var(--radius-sm,6px)] " +
                  "bg-[var(--surface-2,#181D1A)] text-[var(--brand,#22C55E)]"
                }
              >
                <Globe className="h-5 w-5" aria-hidden="true" />
              </div>
              <h3 className="mt-4 font-sans text-lg font-semibold text-[var(--text,#E8EDEA)]">
                Global Impact
              </h3>
              <p className="mt-2 font-sans text-sm leading-relaxed text-[var(--text-muted,#93A09A)]">
                {/* TODO: Club to provide pillar description */}
                Connecting SVIT engineers with global programs like GSoC, Linux Foundation
                mentorships, and open source fellowships.
              </p>
            </article>
          </div>
        </section>

        {/* ============================================================== */}
        {/* Our Story / History Section (Editorial 2-Column Layout)         */}
        {/* ============================================================== */}
        <section
          aria-labelledby="story-heading"
          className="border-b border-[var(--border,#232A26)] py-16 md:py-24"
        >
          <div className="grid grid-cols-1 gap-12 lg:grid-cols-12">
            {/* Left column: Context */}
            <div className="lg:col-span-5">
              <div className="font-mono text-xs uppercase tracking-widest text-[var(--text-faint,#5E6A64)]">
                &sect; 03 &mdash; OUR STORY
              </div>
              <h2
                id="story-heading"
                className="mt-4 font-serif text-3xl text-[var(--text,#E8EDEA)] sm:text-4xl md:text-5xl"
              >
                From a campus lab to production software
              </h2>
              <p className="mt-4 font-sans text-base leading-relaxed text-[var(--text-muted,#93A09A)]">
                {/* TODO: Club to provide story summary */}
                Founded with a straightforward mission: eliminate the gap between university
                coursework and the open source software that powers modern infrastructure.
              </p>
            </div>

            {/* Right column: Editorial prose & timeline blocks */}
            <div
              className={
                "space-y-8 font-sans text-base leading-relaxed " +
                "text-[var(--text-muted,#93A09A)] lg:col-span-7"
              }
            >
              <div
                className={
                  "rounded-[var(--radius,10px)] border border-[var(--border,#232A26)] " +
                  "bg-[var(--surface,#121614)] p-6 md:p-8"
                }
              >
                <h3 className="font-serif text-xl font-medium text-[var(--text,#E8EDEA)]">
                  {/* TODO: Club to provide story milestone */}
                  The Spark
                </h3>
                <p className="mt-3">
                  {/* TODO: Club to provide paragraph text */}
                  At Sai Vidya Institute of Technology, students often learned data structures and
                  syntax in isolation, without exposure to distributed version control, pull request
                  etiquette, or continuous integration. The OSS Club was born out of discussions in
                  college corridors among developers wanting to build software that lives out in the
                  open.
                </p>
              </div>

              <div
                className={
                  "rounded-[var(--radius,10px)] border border-[var(--border,#232A26)] " +
                  "bg-[var(--surface,#121614)] p-6 md:p-8"
                }
              >
                <h3 className="font-serif text-xl font-medium text-[var(--text,#E8EDEA)]">
                  {/* TODO: Club to provide story milestone */}
                  Where We Are Today
                </h3>
                <p className="mt-3">
                  {/* TODO: Club to provide paragraph text */}
                  Today, the club serves as the hub for open-source initiatives on campus. We run
                  collaborative sprints, maintain open-source campus platforms, host guest lectures
                  from industry engineers, and foster a culture where every member has code shipped
                  to public repositories before graduating.
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* ============================================================== */}
        {/* Faculty Coordinator Section                                     */}
        {/* ============================================================== */}
        <section
          aria-labelledby="faculty-heading"
          className="border-b border-[var(--border,#232A26)] py-16 md:py-24"
        >
          <div className="font-mono text-xs uppercase tracking-widest text-[var(--text-faint,#5E6A64)]">
            &sect; 04 &mdash; FACULTY LEADERSHIP
          </div>

          <h2
            id="faculty-heading"
            className="mt-4 font-serif text-3xl text-[var(--text,#E8EDEA)] sm:text-4xl"
          >
            Academic mentorship &amp; guidance
          </h2>

          <div className="mt-8 max-w-2xl">
            <div
              className={
                "rounded-[var(--radius,10px)] border border-[var(--border,#232A26)] " +
                "bg-[var(--surface,#121614)] p-6 sm:p-8"
              }
            >
              <div className="flex flex-col gap-6 sm:flex-row sm:items-center">
                {/* Faculty Avatar Placeholder */}
                <div
                  className="flex h-20 w-20 shrink-0 items-center justify-center rounded-full border-2 border-dashed border-[var(--border-strong,#33403A)] bg-[var(--surface-2,#181D1A)] text-[var(--text-muted,#93A09A)]"
                  aria-label="Faculty coordinator avatar placeholder"
                >
                  <GraduationCap
                    className="h-9 w-9 text-[var(--brand,#22C55E)]"
                    aria-hidden="true"
                  />
                </div>

                <div className="space-y-1">
                  <span
                    className={
                      "font-mono text-xs uppercase tracking-wider " + "text-[var(--brand,#22C55E)]"
                    }
                  >
                    Faculty Coordinator
                  </span>
                  <h3 className="font-sans text-xl font-semibold text-[var(--text,#E8EDEA)]">
                    {/* TODO: Club to provide faculty coordinator name */}
                    Faculty Coordinator Name
                  </h3>
                  <p className="font-sans text-sm text-[var(--text-muted,#93A09A)]">
                    {/* TODO: Club to provide faculty coordinator title & department */}
                    Department of Computer Science &amp; Engineering, SVIT Bengaluru
                  </p>
                </div>
              </div>

              <blockquote
                className={
                  "mt-6 border-l-2 border-[var(--brand,#22C55E)] pl-4 font-sans " +
                  "text-sm italic leading-relaxed text-[var(--text-muted,#93A09A)]"
                }
              >
                {/* TODO: Club to provide faculty coordinator quote / message */}
                &ldquo;Open source software bridges the gap between academic theory and real-world
                software craftsmanship. Our students are building skills that directly align with
                global engineering practices.&rdquo;
              </blockquote>
            </div>
          </div>
        </section>

        {/* ============================================================== */}
        {/* Code of Conduct Section                                         */}
        {/* ============================================================== */}
        <section aria-labelledby="conduct-heading" className="py-16 md:py-24">
          <div
            className={
              "rounded-[var(--radius,10px)] border border-[var(--border,#232A26)] " +
              "bg-[var(--surface,#121614)] p-8 md:p-12"
            }
          >
            <div className="font-mono text-xs uppercase tracking-widest text-[var(--text-faint,#5E6A64)]">
              &sect; 05 &mdash; COMMUNITY STANDARDS
            </div>

            <div className="mt-4 flex flex-col justify-between gap-6 md:flex-row md:items-center">
              <div className="max-w-2xl">
                <h2
                  id="conduct-heading"
                  className="font-serif text-2xl text-[var(--text,#E8EDEA)] sm:text-3xl"
                >
                  Code of Conduct
                </h2>
                <p className="mt-2 font-sans text-base leading-relaxed text-[var(--text-muted,#93A09A)]">
                  We are committed to providing a friendly, safe, and welcoming environment for all
                  participants, regardless of experience level, identity, or background. We expect
                  all club members and contributors to uphold these values across our repositories,
                  events, and communication channels.
                </p>
              </div>

              <div className="shrink-0">
                <Link
                  href="/CODE_OF_CONDUCT.md"
                  className="inline-flex items-center gap-2 rounded-[var(--radius-sm,6px)] border border-[var(--border-strong,#33403A)] bg-[var(--surface-2,#181D1A)] px-5 py-2.5 font-sans text-sm font-medium text-[var(--text,#E8EDEA)] transition-colors hover:border-[var(--brand,#22C55E)] hover:text-[var(--brand,#22C55E)] focus:outline-none focus:ring-2 focus:ring-[var(--focus,#7CE3A6)] focus:ring-offset-2 focus:ring-offset-[var(--bg,#0B0D0C)]"
                >
                  <span>Read Code of Conduct</span>
                  <ArrowUpRight className="h-4 w-4" aria-hidden="true" />
                </Link>
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
