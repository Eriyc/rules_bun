import { nanoid } from "nanoid";
const app = document.querySelector("#app");

if (app) {
  const id = nanoid();
  app.textContent = "Hello from monorepo app B " + id;
}

console.log("Hello from monorepo app B");
