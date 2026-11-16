import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

describe("Utility functions", () => {
  it("cn merges classes correctly", () => {
    expect(cn("px-2", "py-1")).toBe("px-2 py-1");
    expect(cn("px-2", { "text-red-500": true, "text-blue-500": false })).toBe("px-2 text-red-500");
  });
});

describe("UI Components", () => {
  it("renders Button component", () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole("button", { name: /click me/i })).toBeInTheDocument();
  });

  it("renders Card component with default h3 heading", () => {
    render(
      <Card>
        <CardHeader>
          <CardTitle>Test Card</CardTitle>
        </CardHeader>
        <CardContent>Content</CardContent>
      </Card>
    );
    const heading = screen.getByRole("heading", { level: 3, name: "Test Card" });
    expect(heading).toBeInTheDocument();
    expect(screen.getByText("Content")).toBeInTheDocument();
  });

  it("renders CardTitle with asChild correctly", () => {
    render(
      <CardTitle asChild>
        <h1>Custom Heading</h1>
      </CardTitle>
    );
    expect(screen.getByRole("heading", { level: 1, name: "Custom Heading" })).toBeInTheDocument();
  });

  it("renders Badge component", () => {
    render(<Badge>New</Badge>);
    expect(screen.getByText("New")).toBeInTheDocument();
  });
});
