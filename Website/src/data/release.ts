import release from './release.json';
export const macVersion = release.macVersion;
export const windowsVersion = release.windowsVersion;
export const macAssetURL = (file: string) => `https://github.com/leviackerman05/dictate/releases/download/${macVersion}/${file}`;
export const windowsReleaseURL = `https://github.com/leviackerman05/dictate/releases/tag/${windowsVersion}`;
export const windowsAssetURL = (file: string) => `https://github.com/leviackerman05/dictate/releases/download/${windowsVersion}/${file}`;
