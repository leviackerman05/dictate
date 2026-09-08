import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
if (process.platform === 'win32') {
  const script = fileURLToPath(new URL('./prepare-windows-runtime.ps1', import.meta.url));
  const args = ['-NoProfile', '-File', script];
  let result = spawnSync('pwsh.exe', args, { stdio: 'inherit' });
  if (result.error?.code === 'ENOENT') {
    // A PowerShell 7 parent can pass incompatible module paths to Windows
    // PowerShell 5. Let the fallback reconstruct its own standard module path.
    const env = { ...process.env };
    for (const key of Object.keys(env)) if (key.toLowerCase() === 'psmodulepath') delete env[key];
    result = spawnSync('powershell.exe', args, { stdio: 'inherit', env });
  }
  if (result.error) throw result.error;
  process.exit(result.status ?? 1);
}
