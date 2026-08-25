import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const page = await readFile(resolve("src/pages/index.astro"), "utf8");
const required = ["#top", "#flow", "#privacy", "#release", "https://github.com/leviackerman05/dictate"];
const missing = required.filter((link) => !page.includes(link));
if (missing.length) {
  console.error(`Website link check failed: ${missing.join(", ")}`);
  process.exit(1);
}
console.log(`Website link check passed (${required.length} anchors/references).`);
