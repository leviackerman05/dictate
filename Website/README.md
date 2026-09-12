# Dictate website

Static Astro site hosted at [dictate-macos.vercel.app](https://dictate-macos.vercel.app).

## Develop and check

From `Website`:

```sh
npm ci
npm run dev
```

Before deployment:

```sh
npm run check
npm test
npm run check:links
npm run build
```

Download links for both Mac and Windows use the version in
`src/data/release.json`, which must match `../Release/version.txt`. Publish the
GitHub release assets before deploying a new download version. Verify public
assets with `npm run check:links -- --remote`.

## Deploy

From `Website`, using the existing Vercel project:

```sh
npx vercel --prod
```

The project uses `npm ci` and `npm run build`, serving the generated `dist/`
directory. Vercel supplies the production hostname for canonical and social URLs.
