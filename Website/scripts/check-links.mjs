import {readFile} from 'node:fs/promises';
const home = await readFile('src/pages/index.astro', 'utf8');
const download = await readFile('src/pages/download.astro', 'utf8');
const version = (await readFile('../Release/version.txt','utf8')).trim();
if(JSON.parse(await readFile('src/data/release.json','utf8')).version!==version)throw new Error('Website release version differs from installer manifest');
for (const id of ['top','flow','privacy','release']) if (!home.includes(`id="${id}"`)) throw new Error(`Missing #${id}`);
for (const file of ['Dictate.dmg','Dictate-Windows-x64-setup.exe','Dictate-Linux-x64.deb','Dictate-Linux-x64.AppImage','manifest.json']) {
  if (!download.includes(`assetURL('${file}')`)) throw new Error(`Missing ${file}`);
  if (process.argv.includes('--remote')) {
    const url=`https://github.com/leviackerman05/dictate/releases/download/${version}/${file}`;
    const response=await fetch(url,{method:'HEAD'});
    if(!response.ok) throw new Error(`Unavailable ${file}: ${response.status}`);
  }
}
console.log(`Download links passed for ${version}${process.argv.includes('--remote')?' (public assets verified)':' (source check; use --remote after publishing)'}.`);
