# Dictate website

This is a separate Astro surface for Dictate. It is intentionally smaller and quieter than a dashboard: one product promise, one synthetic interaction, three product beats, and the Color Index palette.

Production: [dictate-macos.vercel.app](https://dictate-macos.vercel.app)

## Local development

```sh
npm install
npm run dev
```

Run the full static checks before previewing:

```sh
npm run check
npm run check:links
npm run build
npm run preview
```

Both download CTAs use GitHub's stable latest-release asset URL:

```text
https://github.com/leviackerman05/dictate/releases/latest/download/Dictate.dmg
```

The release workflow always uploads the DMG with that exact filename, so the website does not need to know the current version tag.

## Deploy

The site is a static Astro build hosted on Vercel. From this directory:

```sh
npx vercel@latest --prod
```

Vercel supplies the production hostname during the build so canonical and social URLs point to the live deployment.
