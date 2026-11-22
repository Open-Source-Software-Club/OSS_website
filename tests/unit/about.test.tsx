import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import AboutPage, { generateMetadata } from "@/app/(public)/about/page";

describe("AboutPage Component and Metadata", () => {
  it("generates correct SEO metadata per acceptance criteria", async () => {
    const metadata = await generateMetadata();

    expect(metadata.title).toBe("About -- OSS Club SVIT");
    expect(metadata.description).toContain("OSS Club");
    expect(metadata.openGraph?.title).toBe("About -- OSS Club SVIT");
    expect(metadata.openGraph?.url).toBe("/about");
  });

  it("renders the hero section with heading and subtitle", () => {
    render(<AboutPage />);

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: /Read the source\. Then write the next commit\./i,
      })
    ).toBeInTheDocument();
    expect(
      screen.getByText(/The Open Source Software Club at Sai Vidya Institute of Technology/i)
    ).toBeInTheDocument();
  });

  it("renders all four core pillars with icons and titles", () => {
    render(<AboutPage />);

    expect(screen.getByRole("heading", { level: 3, name: "Production Code" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 3, name: "Open Community" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 3, name: "Learn in Public" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 3, name: "Global Impact" })).toBeInTheDocument();
  });

  it("renders the our story section", () => {
    render(<AboutPage />);

    expect(
      screen.getByRole("heading", { level: 2, name: /From a campus lab to production software/i })
    ).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 3, name: "The Spark" })).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { level: 3, name: "Where We Are Today" })
    ).toBeInTheDocument();
  });

  it("renders the faculty coordinator card with avatar placeholder and quote", () => {
    render(<AboutPage />);

    expect(
      screen.getByRole("heading", { level: 3, name: "Faculty Coordinator Name" })
    ).toBeInTheDocument();
    expect(screen.getByText(/Department of Computer Science & Engineering/i)).toBeInTheDocument();
    expect(screen.getByText(/Open source software bridges the gap/i)).toBeInTheDocument();
  });

  it("links to the Code of Conduct", () => {
    render(<AboutPage />);

    const link = screen.getByRole("link", { name: /Read Code of Conduct/i });
    expect(link).toBeInTheDocument();
    expect(link).toHaveAttribute("href", "/CODE_OF_CONDUCT.md");
  });
});
