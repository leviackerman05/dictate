import { defineConfig } from "astro/config";

const productionHost = process.env.VERCEL_PROJECT_PRODUCTION_URL;

export default defineConfig({
  site: productionHost ? `https://${productionHost}` : "https://dictate-macos.vercel.app",
  output: "static",
  compressHTML: true,
  // The landing page stays self-contained and loads correctly from any CDN.
  build: { inlineStylesheets: "always" }
});
