import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { detectPlatform, isPlatform } from '../src/lib/platform.ts';

test('desktop hints select a compatible OS family, not an architecture', () => {
  assert.equal(detectPlatform({ platform: 'MacIntel', userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }), 'mac');
  assert.equal(detectPlatform({ platform: 'Win32' }), 'windows');
  assert.equal(detectPlatform({ platform: 'Linux x86_64' }), null);
  assert.equal(detectPlatform({ userAgentData: { platform: 'Windows' } }), 'windows');
});
test('mobile, iPad desktop mode, ChromeOS and unknown browsers need an explicit choice', () => {
  for (const browser of [
    { platform: 'MacIntel', maxTouchPoints: 5 },
    { platform: 'iPhone' },
    { userAgent: 'Mozilla/5.0 (Linux; Android 14)', platform: 'Linux armv8l' },
    { userAgent: 'Mozilla/5.0 (X11; CrOS x86_64)', platform: 'Linux x86_64' },
    {},
  ]) assert.equal(detectPlatform(browser), null);
});
test('only supported manual overrides are accepted', () => {
  for (const name of ['mac', 'windows']) assert.equal(isPlatform(name), true);
  for (const name of [null, '', 'linux', 'android', '__proto__', 'MAC']) assert.equal(isPlatform(name), false);
});
