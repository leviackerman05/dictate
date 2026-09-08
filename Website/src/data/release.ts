import { readFileSync } from 'node:fs';
export const version = readFileSync(new URL('../../../Release/version.txt', import.meta.url), 'utf8').trim();
export const releaseURL = `https://github.com/leviackerman05/dictate/releases/tag/${version}`;
export const assetURL = (file: string) => `https://github.com/leviackerman05/dictate/releases/download/${version}/${file}`;
