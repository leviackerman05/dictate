// Optional frontend integration test; start npm run dev in Desktop first.
// Requires Playwright and its Chromium, or BROWSER_EXECUTABLE. Uses synthetic IPC only.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs=require('fs');
(async()=>{
 const browser=await chromium.launch({...(process.env.BROWSER_EXECUTABLE?{executablePath:process.env.BROWSER_EXECUTABLE}:{}),headless:true});
 const page=await browser.newPage({viewport:{width:1120,height:750},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.addInitScript(()=>{
 let callbacks={},next=1;const listeners=[];
 window.emitLevel=level=>listeners.filter(v=>v.event==='level').forEach(v=>callbacks[v.id]?.({event:v.event,payload:level}));
 window.emitState=()=>listeners.filter(v=>v.event==='state-changed').forEach(v=>callbacks[v.id]?.({event:v.event,payload:null}));
 const now=new Date();
 const stamp=days=>{const value=new Date(now);value.setDate(value.getDate()-days);return value.toISOString()};
 window.mock={data:{preferences:{model:'parakeet',keepHistory:true,retention:'forever',recordingMode:'holdToTalk',shortcut:'ControlRight',appearance:'light',onboardingDone:true,autoInsert:true,showReadyIndicator:true},history:[
  {id:'today-1',timestamp:stamp(0),originalTranscript:'Draft the launch note and share it with the team.',correctedText:'Draft the launch note and share it with the team.',duration:7.4,insertionResult:'insertedViaPaste',correctionAudit:[],isPinned:false},
  {id:'today-2',timestamp:stamp(0),originalTranscript:'Remember to test right control in Notepad.',correctedText:'Remember to test Right Ctrl in Notepad.',duration:5.2,insertionResult:'copiedToClipboard',correctionAudit:[{heard:'right control',written:'Right Ctrl'}],isPinned:true},
  {id:'yesterday',timestamp:stamp(1),originalTranscript:'Dictate keeps every recording local.',correctedText:'Dictate keeps every recording local.',duration:4.1,insertionResult:'insertedViaPaste',correctionAudit:[],isPinned:false}
 ],dictionary:[
  {id:'codex',kind:'correction',sourcePhrase:'codecs',targetPhrase:'Codex',notes:null,isEnabled:true,createdAt:stamp(14),updatedAt:stamp(2)},
  {id:'parakeet',kind:'vocabulary',sourcePhrase:'Parakeet',targetPhrase:null,notes:null,isEnabled:true,createdAt:stamp(8),updatedAt:stamp(1)}
 ],recovery:null},phase:'idle',models:[{id:'tiny',name:'Whisper Tiny',bytes:77691713},{id:'base',name:'Whisper Base',bytes:147951465},{id:'small',name:'Whisper Small',bytes:487601967},{id:'parakeet',name:'NVIDIA Parakeet v3',bytes:670479942}],installed:['parakeet'],ready:true,settingUp:false,notice:null,shortcutError:null,capability:'Text is inserted into the current editable field when Windows allows it. Otherwise, copy your words.',platform:'windows',version:'1.1.0-beta.8'};
 window.calls=[];
 window.__TAURI_INTERNALS__={transformCallback:fn=>{let id=next++;callbacks[id]=fn;return id},unregisterCallback:id=>delete callbacks[id],invoke:async(cmd,args)=>{
 window.calls.push({cmd,args});
 if(cmd==='get_state')return structuredClone(window.mock);
 if(cmd==='save_preferences'){if(window.failSave)throw Error('Synthetic save failure');window.mock.data.preferences=args.preferences;}
 if(cmd==='save_dictionary')window.mock.data.dictionary=args.entries;
 if(cmd==='setup_model'){window.mock.installed.push(args.id);window.mock.ready=true;window.mock.data.preferences.model=args.id;}
 if(cmd==='start_recording')window.mock.phase='listening';
 if(cmd==='finish_recording'){window.mock.phase='idle';window.mock.data.recovery='A synthetic transcript for recovery testing.';}
 if(cmd==='cancel_recording')window.mock.phase='idle';
 if(cmd==='copy_text')window.mock.data.recovery=null;
 if(cmd==='plugin:event|listen'){listeners.push({event:args.event,id:args.handler});return next++;}
 if(cmd.startsWith('plugin:event|'))return next++;
 return null;
 }};
 });
 const preview=process.env.DICTATE_PREVIEW_URL || 'http://127.0.0.1:1420';
 await page.goto(preview);await page.waitForSelector('nav');
 const dir=process.env.DICTATE_UI_OUTPUT || require('path').resolve(__dirname,'../../docs/evidence/ui/windows-beta8');fs.mkdirSync(dir,{recursive:true});
 const results=[];
 for(const theme of ['light','dark']){

  // State is refreshed by a harmless action that invokes the mock.
  await page.locator('nav [data-section="settings"]').click();
  await page.locator(`[name="appearance"][value="${theme}"]`).check();
  await page.waitForFunction(theme=>window.mock.data.preferences.appearance===theme,theme);
  if(await page.evaluate(()=>document.documentElement.dataset.theme)!==theme)throw new Error('Wrong theme');
  await page.locator('[data-action="show-setup"]').click();
  await page.screenshot({path:`${dir}/setup-${theme}.png`,fullPage:true});
  await page.locator('.onboarding-panel [data-action="complete-setup"]').first().click();
  await page.locator('nav [data-section="dashboard"]').click();
  for(const section of ['dashboard','history','dictionary','statistics','models','settings']){
   await page.locator(`nav [data-section="${section}"]`).click();
   await page.screenshot({path:`${dir}/${section}-${theme}.png`,fullPage:true});
   results.push({theme,section,...await page.evaluate(()=>{const main=document.querySelector('main');return {overflow:document.documentElement.scrollWidth>innerWidth,bodyOverflow:document.documentElement.scrollHeight>innerHeight,heading:document.querySelector('h1').textContent,mainScroll:main?main.scrollHeight-main.clientHeight:0}})});
  }
  await page.locator('[data-action="settings-tab"][data-id="audio"]').click();
  await page.screenshot({path:`${dir}/settings-audio-${theme}.png`,fullPage:true});
  await page.locator('[data-action="settings-tab"][data-id="permissions"]').click();
  await page.screenshot({path:`${dir}/settings-permissions-${theme}.png`,fullPage:true});
  await page.locator('[data-action="settings-tab"][data-id="general"]').click();
 }
 await page.locator('[name="showReadyIndicator"]').uncheck();
 await page.waitForFunction(()=>window.mock.data.preferences.showReadyIndicator===false);
 await page.locator('[name="showReadyIndicator"]').check();
 await page.waitForFunction(()=>window.mock.data.preferences.showReadyIndicator===true);
 await page.locator('[data-action="capture-shortcut"]').click();await page.keyboard.press('ControlRight');await page.waitForTimeout(100);
 if(await page.locator('.shortcut-capture').innerText()!=='Right Ctrl') throw new Error('Right Ctrl capture failed');
 await page.locator('[name="recordingMode"][value="clickToToggle"]').check();
 await page.locator('[name="appearance"][value="light"]').check();
 await page.waitForFunction(()=>window.mock.data.preferences.recordingMode==='clickToToggle'&&window.mock.data.preferences.appearance==='light');
 await page.locator('[data-action="settings-tab"][data-id="permissions"]').click();
 await page.locator('[name="autoInsert"]').uncheck();
 await page.waitForFunction(()=>window.mock.data.preferences.autoInsert===false);
 const prefs=await page.evaluate(()=>window.mock.data.preferences);
 if(prefs.shortcut!=='ControlRight'||prefs.recordingMode!=='clickToToggle'||prefs.appearance!=='light'||prefs.autoInsert!==false)throw new Error('Preferences failed '+JSON.stringify(prefs));
 await page.locator('[data-action="settings-tab"][data-id="general"]').click();
 await page.locator('[data-action="capture-shortcut"]').click();await page.keyboard.press('Control+Shift+K');await page.waitForFunction(()=>window.mock.data.preferences.shortcut==='Ctrl+Shift+KeyK');
 if((await page.evaluate(()=>window.mock.data.preferences.shortcut))!=='Ctrl+Shift+KeyK')throw new Error('Chord capture failed');
 await page.locator('[data-action="shortcut-preset"][data-id="MouseBack"]').click();await page.waitForFunction(()=>window.mock.data.preferences.shortcut==='MouseBack');
 if((await page.evaluate(()=>window.mock.data.preferences.shortcut))!=='MouseBack')throw new Error('Mouse preset failed');
 await page.locator('nav [data-section="models"]').click();
 await page.locator('[data-action="select-model"][data-id="tiny"]').click();
 await page.locator('[data-action="select-model"][data-id="parakeet"]').first().click();
 if(!(await page.evaluate(()=>window.mock.ready&&window.mock.data.preferences.model==='parakeet')))throw new Error('Parakeet selection failed');
 // Exercise immediate persistence and recoverable save failures, not just layout.
 await page.locator('nav [data-section="settings"]').click();
 await page.locator('[data-action="settings-tab"][data-id="general"]').click();
 await page.evaluate(()=>window.failSave=true);
 await page.locator('[name="keepHistory"]').evaluate(element=>element.click());
 await page.getByText('Synthetic save failure').waitFor();
 await page.waitForFunction(()=>document.querySelector('[name="keepHistory"]')?.checked===true);
 if(!(await page.locator('[name="keepHistory"]').isChecked()))throw Error('Failed automatic save did not restore persisted value');
 await page.evaluate(()=>window.failSave=false);
 await page.locator('[name="keepHistory"]').uncheck();
 await page.waitForFunction(()=>window.mock.data.preferences.keepHistory===false);
 await page.locator('[data-action="shortcut-preset"][data-id="F8"]').click();
 await page.waitForFunction(()=>window.mock.data.preferences.shortcut==='F8');
 await page.locator('[data-action="settings-tab"][data-id="permissions"]').click();
 await page.locator('[data-action="open-privacy"]').click();
 await page.waitForFunction(()=>window.calls.some(call=>call.cmd==='plugin:opener|open_url'));
 await page.locator('nav [data-section="dictionary"]').click();
 await page.locator('[data-action="add-entry"]').click();
 await page.locator('[name="source"]').fill('cloud code');await page.locator('[name="target"]').fill('Claude Code');
 await page.evaluate(()=>window.emitState());await page.waitForTimeout(50);
 if(await page.locator('[name="source"]').inputValue()!=='cloud code')throw Error('Refresh discarded dictionary draft');
 await page.locator('#dictionary-form button[type="submit"]').click();
 if(!(await page.evaluate(()=>window.mock.data.dictionary.some(entry=>entry.targetPhrase==='Claude Code'))))throw Error('Dictionary save failed');
 await page.locator('nav [data-section="dashboard"]').click();
 if(await page.locator('.brand-mark img[src="/dictate-mark.svg"]').count()!==1)throw Error('Shared Dictate mark is missing');
 if(await page.locator('.chart-point').count()!==7)throw Error('Dashboard graph point alignment layer is missing');
 await page.locator('.chart-point').last().hover();
 if(!(await page.locator('.chart-point').last().getAttribute('aria-label'))?.includes('words'))throw Error('Dashboard graph value is unavailable');
 await page.locator('nav [data-section="statistics"]').click();
 await page.locator('.bar-column').last().hover();
 if(!(await page.locator('.bar-column').last().getAttribute('aria-label'))?.includes('words'))throw Error('Statistics graph value is unavailable');
 await page.locator('nav [data-section="dashboard"]').click();await page.locator('[data-action="record"]').click();
 if(!(await page.locator('[data-action="finish"]').first().getAttribute('class'))?.includes('recording'))throw Error('Recording button did not use the red active treatment');
 if(await page.locator('[data-action="finish"] .stop-mark').count()!==1)throw Error('Recording stop mark is missing');
 await page.locator('[data-action="finish"]').first().click();await page.getByText('A synthetic transcript for recovery testing.',{exact:true}).waitFor();
 await page.locator('[data-action="copy-recovery"]').click();
 if(await page.locator('.recovery').count())throw Error('Copied recovery was not cleared');
 await page.setViewportSize({width:760,height:560});
 for(const section of ['dashboard','settings','models']){await page.locator(`nav [data-section="${section}"]`).click();await page.screenshot({path:`${dir}/${section}-minimum.png`,fullPage:true});results.push({section,size:'minimum',overflow:await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)});}
 await page.locator('nav [data-section="settings"]').click();await page.locator('[data-action="settings-tab"][data-id="general"]').click();await page.locator('[data-action="show-setup"]').click();await page.screenshot({path:`${dir}/setup-minimum.png`,fullPage:true});
 await page.setViewportSize({width:108,height:52});await page.goto(`${preview}?overlay=1`);await page.waitForSelector('.recording-overlay');
 const idleBounds=await page.locator('.recording-overlay').boundingBox();
 if(idleBounds.width!==32 || idleBounds.height!==16)throw Error('Idle indicator dimensions wrong');
 await page.screenshot({path:`${dir}/overlay-idle.png`});
 await page.evaluate(()=>{window.mock.phase='listening';window.emitState();});await page.waitForTimeout(100);await page.screenshot({path:`${dir}/overlay-listening.png`});
 if(await page.locator('.recording-overlay button').count())throw Error('Recorder pebble must not contain actions');
 await page.evaluate(()=>window.emitLevel(.04));
 await page.waitForTimeout(50);
 if(await page.locator('.pebble-bar').evaluateAll(bars=>Math.max(...bars.map(b=>parseFloat(b.style.height))))<=6)throw Error('Normal speech meter response too weak');
 if(await page.locator('.pebble-bar').count()!==9)throw Error('Recorder pebble level bars missing');
 await page.evaluate(()=>{window.mock.phase='finalizing';window.emitState();});await page.waitForTimeout(50);await page.screenshot({path:`${dir}/overlay-processing.png`});
 fs.writeFileSync(`${dir}/ui-check.json`,JSON.stringify({scope:'Chromium preview with synthetic IPC on macOS; native Windows packaging is verified by GitHub Actions',results,errors,preferences:prefs,checks:['Mac-parity light and dark screens','shared Dictate brand mark','dashboard and statistics hover values','red recording button and filled stop mark','system privacy URL opener','onboarding dismissal','compact action-free recorder pebble','single modifier capture','chord capture','mouse preset','segmented preference autosave','switch autosave','Parakeet selection','automatic save failure recovery','dictionary draft across refresh','dictionary save','record and recovery copy']},null,2));
 console.log(JSON.stringify({results,errors}));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
