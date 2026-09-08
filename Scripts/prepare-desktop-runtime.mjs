import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
if (process.platform === 'win32') {
  const script = fileURLToPath(new URL('./prepare-windows-runtime.ps1', import.meta.url));
  const result = spawnSync('powershell.exe', ['-NoProfile', '-File', script], { stdio: 'inherit' });
  if (result.error) throw result.error;
  process.exit(result.status ?? 1);
}
