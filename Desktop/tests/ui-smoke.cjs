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
 window.emitState=()=>listeners.filter(v=>v.event==='state-changed').forEach(v=>callbacks[v.id]?.({event:v.event,payload:null}));
 window.mock={data:{preferences:{model:'tiny',keepHistory:true,retention:'forever',recordingMode:'holdToTalk',shortcut:'ControlRight',appearance:'light',onboardingDone:true,autoInsert:true},history:[],dictionary:[],recovery:null},phase:'idle',models:[{id:'tiny',name:'Whisper Tiny',bytes:77691713},{id:'base',name:'Whisper Base',bytes:147951465},{id:'small',name:'Whisper Small',bytes:487601967},{id:'parakeet',name:'NVIDIA Parakeet v3',bytes:670479942}],installed:[],ready:false,settingUp:false,notice:null,shortcutError:null,capability:'Text is inserted into the current editable field when Windows allows it. Otherwise, copy your words.',platform:'windows',version:'1.1.0-beta.5'};
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
 await page.goto(process.env.DICTATE_PREVIEW_URL || 'http://127.0.0.1:1420');await page.waitForSelector('nav');
 const dir=require('path').resolve(__dirname,'../../docs/evidence/ui/windows-beta5');fs.mkdirSync(dir,{recursive:true});
 const results=[];
 for(const theme of ['light','dark']){

  // State is refreshed by a harmless action that invokes the mock.
  await page.locator('nav [data-section="settings"]').click();
  await page.locator(`[name="appearance"][value="${theme}"]`).check();await page.locator('#save-settings').click();
  if(await page.evaluate(()=>document.documentElement.dataset.theme)!==theme)throw new Error('Wrong theme');
  await page.locator('[data-action="show-setup"]').click();
  await page.screenshot({path:`${dir}/setup-${theme}.png`,fullPage:true});
  await page.locator('nav [data-section="dashboard"]').click();
  for(const section of ['dashboard','history','dictionary','statistics','models','settings']){
   await page.locator(`nav [data-section="${section}"]`).click();
   await page.screenshot({path:`${dir}/${section}-${theme}.png`,fullPage:true});
   results.push({theme,section,...await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,bodyOverflow:document.documentElement.scrollHeight>innerHeight,heading:document.querySelector('h1').textContent,mainScroll:document.querySelector('main').scrollHeight-document.querySelector('main').clientHeight}))});
  }
 }
 await page.locator('[data-action="capture-shortcut"]').click();await page.keyboard.press('ControlRight');await page.waitForTimeout(100);
 if(await page.locator('.shortcut-capture').innerText()!=='Right Ctrl') throw new Error('Right Ctrl capture failed');
 await page.locator('[name="recordingMode"][value="clickToToggle"]').check();
 await page.locator('[name="appearance"][value="light"]').check();
 await page.locator('[name="autoInsert"]').uncheck();
 await page.locator('#save-settings').click();
 const prefs=await page.evaluate(()=>window.mock.data.preferences);
 if(prefs.shortcut!=='ControlRight'||prefs.recordingMode!=='clickToToggle'||prefs.appearance!=='light'||prefs.autoInsert!==false)throw new Error('Preferences failed '+JSON.stringify(prefs));
 await page.locator('[data-action="capture-shortcut"]').click();await page.keyboard.press('Control+Shift+K');await page.waitForTimeout(100);await page.locator('#save-settings').click();
 if((await page.evaluate(()=>window.mock.data.preferences.shortcut))!=='Ctrl+Shift+KeyK')throw new Error('Chord capture failed');
 await page.locator('[data-action="shortcut-preset"][data-id="MouseBack"]').click();await page.locator('#save-settings').click();
 if((await page.evaluate(()=>window.mock.data.preferences.shortcut))!=='MouseBack')throw new Error('Mouse preset failed');
 await page.locator('nav [data-section="models"]').click();await page.locator('[data-action="select-model"][data-id="parakeet"]').click();
 if(!(await page.evaluate(()=>window.mock.ready&&window.mock.data.preferences.model==='parakeet')))throw new Error('Parakeet selection failed');
 // Exercise draft retention and recoverable save failures, not just layout.
 await page.locator('nav [data-section="settings"]').click();
 await page.locator('[name="keepHistory"]').uncheck();
 await page.locator('[data-action="shortcut-preset"][data-id="F8"]').click();
 if(await page.locator('[name="keepHistory"]').isChecked())throw Error('Preset discarded unsaved settings');
 await page.evaluate(()=>{window.failSave=true;window.emitState();});
 await page.locator('#save-settings').click();await page.getByText('Synthetic save failure').waitFor();
 if(await page.locator('[name="keepHistory"]').isChecked())throw Error('Failed save discarded settings');
 if(await page.evaluate(()=>document.activeElement?.id)!=='save-settings')throw Error('Lost submit focus');
 await page.evaluate(()=>window.failSave=false);await page.locator('#save-settings').click();
 await page.locator('nav [data-section="dictionary"]').click();
 await page.locator('[name="source"]').fill('cloud code');await page.locator('[name="target"]').fill('Claude Code');
 await page.evaluate(()=>window.emitState());await page.waitForTimeout(50);
 if(await page.locator('[name="source"]').inputValue()!=='cloud code')throw Error('Refresh discarded dictionary draft');
 await page.locator('#dictionary-form button[type="submit"]').click();
 if((await page.evaluate(()=>window.mock.data.dictionary[0]?.targetPhrase))!=='Claude Code')throw Error('Dictionary save failed');
 await page.locator('nav [data-section="dashboard"]').click();await page.locator('[data-action="record"]').click();
 await page.locator('[data-action="finish"]').first().click();await page.getByText('A synthetic transcript for recovery testing.',{exact:true}).waitFor();
 await page.locator('[data-action="copy-recovery"]').click();
 if(await page.locator('.recovery').count())throw Error('Copied recovery was not cleared');
 await page.setViewportSize({width:760,height:560});
 for(const section of ['dashboard','settings','models']){await page.locator(`nav [data-section="${section}"]`).click();await page.screenshot({path:`${dir}/${section}-minimum.png`,fullPage:true});results.push({section,size:'minimum',overflow:await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)});}
 await page.locator('nav [data-section="settings"]').click();await page.locator('[data-action="show-setup"]').click();await page.screenshot({path:`${dir}/setup-minimum.png`,fullPage:true});
 fs.writeFileSync(`${dir}/ui-check.json`,JSON.stringify({scope:'Chromium preview with synthetic IPC on macOS; not native Windows certification',results,errors,preferences:prefs,checks:['single modifier capture','chord capture','mouse preset','segmented preferences save','switch save','Parakeet selection','settings draft across shortcut render','save failure preserves draft and focus','dictionary draft across refresh','dictionary save','record and recovery copy']},null,2));
 console.log(JSON.stringify({results,errors}));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
