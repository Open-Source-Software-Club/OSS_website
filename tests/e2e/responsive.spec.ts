import { expect, test } from "@playwright/test";

const routes = ["/", "/about", "/projects", "/events", "/contact"];
const viewports = [360, 640, 768, 1024, 1280, 1440];

for (const route of routes) {
  for (const width of viewports) {
    test(`${route} has no overflow at ${width}px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.goto(route);

      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth
      );

      expect(overflow).toBe(false);

      if (width < 640) {
        const undersizedTargets = await page.evaluate(() =>
          Array.from(document.querySelectorAll<HTMLElement>("a, button, input"))
            .filter((element) => {
              const rect = element.getBoundingClientRect();
              return rect.width > 0 && rect.height > 0 && rect.height < 44;
            })
            .map((element) => ({
              tag: element.tagName,
              text: element.textContent?.trim(),
              height: element.getBoundingClientRect().height,
            }))
        );

        expect(undersizedTargets).toEqual([]);
      }
    });
  }
}

test("mobile menu opens and exposes navigation", async ({ page }) => {
  test.skip(test.info().project.name !== "mobile");
  await page.setViewportSize({ width: 360, height: 800 });
  await page.goto("/");
  await page.getByRole("button", { name: "Menu" }).click();

  await expect(page.getByRole("navigation", { name: "Mobile" })).toBeVisible();
  await expect(
    page
      .getByRole("navigation", { name: "Mobile" })
      .getByRole("link", { name: "Projects", exact: true })
  ).toBeVisible();
});
