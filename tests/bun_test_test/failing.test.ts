import { expect, test } from "bun:test";

test("intentionally fails for manual validation", () => {
  expect(1 + 1).toBe(3);
});
