export type Platform = 'mac' | 'windows';
export const platformNames: Record<Platform, string> = { mac: 'Mac', windows: 'Windows' };
export function isPlatform(value: unknown): value is Platform {
  return value === 'mac' || value === 'windows';
}

// Browser hints only: no account, persistence, or fingerprinting. Architecture
// cannot be inferred reliably, so the installer requirements stay visible.
export function detectPlatform(browser: {
  userAgent?: string;
  platform?: string;
  maxTouchPoints?: number;
  userAgentData?: { platform?: string };
}): Platform | null {
  const ua = browser.userAgent ?? '';
  const platform = browser.userAgentData?.platform || browser.platform || '';
  if (/Android|iPhone|iPad|iPod|Windows Phone|CrOS/i.test(`${ua} ${platform}`)
      || (/Mac/i.test(platform) && (browser.maxTouchPoints ?? 0) > 1)) return null;
  if (/Win/i.test(platform) || /Windows NT/i.test(ua)) return 'windows';
  if (/Mac/i.test(platform) || /Macintosh/i.test(ua)) return 'mac';
  return null;
}
