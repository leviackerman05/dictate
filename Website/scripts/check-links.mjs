import {readFile} from 'node:fs/promises';
const home = await readFile('src/pages/index.astro', 'utf8');
const download = await readFile('src/pages/download.astro', 'utf8');
const macVersion = (await readFile('../Release/version.txt','utf8')).trim();
const windowsVersion = (await readFile('../Release/windows-version.txt','utf8')).trim();
const release = JSON.parse(await readFile('src/data/release.json','utf8'));
if(release.macVersion!==macVersion||release.windowsVersion!==windowsVersion)throw new Error('Website release versions differ from release manifests');
for (const id of ['top','flow','privacy','release']) if (!home.includes(`id="${id}"`)) throw new Error(`Missing #${id}`);
for (const [file, version, helper] of [['Dictate.dmg',macVersion,'macAssetURL'],['Dictate-Windows-x64-setup.exe',windowsVersion,'windowsAssetURL'],['manifest.json',windowsVersion,'windowsAssetURL']]) {
  if (!download.includes(`${helper}('${file}')`)) throw new Error(`Missing ${file}`);
  if (process.argv.includes('--remote')) {
    const url=`https://github.com/leviackerman05/dictate/releases/download/${version}/${file}`;
    const response=await fetch(url,{method:'HEAD'});
    if(!response.ok) throw new Error(`Unavailable ${file}: ${response.status}`);
  }
}
console.log(`Download links passed for Mac ${macVersion} and Windows ${windowsVersion}${process.argv.includes('--remote')?' (public assets verified)':' (source check; use --remote after publishing)'}.`);
