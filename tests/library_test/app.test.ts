import { expect, test } from "bun:test";
import { greeting } from "./helper";

test("uses helper from ts_library dep", () => {
  expect(greeting("test")).toBe("hello-test");
});
