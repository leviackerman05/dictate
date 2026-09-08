import release from './release.json';
export const version = release.version;
export const releaseURL = `https://github.com/leviackerman05/dictate/releases/tag/${version}`;
export const assetURL = (file: string) => `https://github.com/leviackerman05/dictate/releases/download/${version}/${file}`;
