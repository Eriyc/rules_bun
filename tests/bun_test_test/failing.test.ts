import { expect, test } from "bun:test";

test("failing suite", () => {
  expect(1 + 1).toBe(3);
});
