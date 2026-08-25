import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://dictate.local",
  output: "static",
  compressHTML: true,
  // Keep the single-page download site portable: opening dist/index.html
  // directly or hosting it below a repository subpath must not break styles.
  build: { inlineStylesheets: "always" }
});
