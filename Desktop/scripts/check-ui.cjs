const {chromium}=require('playwright');
const fs=require('node:fs');
(async()=>{
 const b=await chromium.launch({headless:true,channel:'chrome'}); const p=await b.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
 const capture=async options=>{await p.evaluate(()=>window.scrollTo(0,0));await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));return p.screenshot(options)};
 const out=require('node:path').resolve(__dirname,'../../docs/evidence/ui/portability');fs.mkdirSync(out,{recursive:true});
 for(const [name,width,height,url,dark] of [['download-desktop',1440,1000,'download',false],['download-mobile',390,844,'download',false],['home-desktop',1440,1000,'',false],['download-dark',1440,1000,'download',true]]){
  await p.setViewportSize({width,height});await p.emulateMedia({colorScheme:dark?'dark':'light'});await p.goto('http://127.0.0.1:4325/'+url);await p.evaluate(()=>document.fonts.ready);await capture({path:`${out}/${name}.png`,fullPage:true});
  if(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error(name+' overflow');
 }
 await p.addInitScript(()=>{
  const now='2026-09-08T00:00:00Z';
  window.mock={data:{preferences:{model:'tiny',keepHistory:true,retention:'forever',recordingMode:'holdToTalk',shortcut:'Ctrl+Shift+Space',appearance:'dark',onboardingDone:false,autoInsert:true},history:[],dictionary:[],recovery:null},phase:'idle',models:[{id:'tiny',name:'Whisper Tiny · multilingual',bytes:77691713},{id:'base',name:'Whisper Base · multilingual',bytes:147951465},{id:'small',name:'Whisper Small · multilingual',bytes:487601967}],installed:[],ready:false,settingUp:false,notice:null,shortcutError:null,capability:'Automatic insertion uses the current editable field. Elevated or inaccessible apps keep text ready to copy.',platform:'windows',version:'1.1.0-beta.2'};
  let id=0;const callbacks={};const listeners=[];window.emitState=()=>listeners.forEach(i=>callbacks[i]?.({event:'state-changed',payload:null}));window.__TAURI_INTERNALS__={transformCallback(fn){callbacks[++id]=fn;return id},unregisterCallback(i){delete callbacks[i]},async invoke(cmd,args){
   if(cmd==='get_state')return structuredClone(window.mock);
   if(cmd==='plugin:event|listen'){if(args.event==='state-changed')listeners.push(args.handler);return ++id;}
   if(cmd==='save_preferences'){if(window.failSave)throw Error('Synthetic save failure');window.mock.data.preferences=args.preferences;return;}
   if(cmd==='save_dictionary'){window.mock.data.dictionary=args.entries;return;}
   if(cmd==='setup_model'){window.mock.ready=true;window.mock.installed=['tiny'];return;}
   if(cmd==='copy_text'){window.mock.data.recovery=null;window.mock.notice='Copied to clipboard.';return;}
   if(cmd==='start_recording'){window.mock.phase='listening';return;}
   if(cmd==='cancel_recording'){window.mock.phase='idle';return;}
   if(cmd==='finish_recording'){window.mock.phase='idle';window.mock.data.recovery='A synthetic transcript for checking the recovery interface.';return;}
   throw Error('Unmocked command: '+cmd);
  }};
 });
 await p.setViewportSize({width:1120,height:780});await p.goto('http://127.0.0.1:1420');await p.getByRole('heading',{name:'Make room for your voice.'}).waitFor();
 await capture({path:out+'/portable-onboarding-dark.png',fullPage:true});
 await p.setViewportSize({width:760,height:600});await capture({path:out+'/portable-onboarding-minimum.png',fullPage:true});
 if(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('portable onboarding overflow');
 await p.getByRole('button',{name:'Set up recommended model'}).click();await p.getByText('Your model is ready',{exact:false}).waitFor();await p.getByRole('button',{name:'Start using Dictate'}).click();
 await p.setViewportSize({width:1120,height:780});await capture({path:out+'/portable-dashboard-dark.png',fullPage:true});
 await p.getByRole('button',{name:'Dictionary',exact:true}).click();
 await p.locator('[name=source]').fill('cloud code');await p.locator('[name=target]').fill('Claude Code');await p.locator('[name=kind]').selectOption('correction');await p.locator('#dictionary-form button[type=submit]').click();await p.getByText('cloud code',{exact:true}).waitFor();
 await capture({path:out+'/portable-dictionary-dark.png',fullPage:true});
 await p.locator('[name=source]').fill('unsaved phrase');await p.locator('[name=target]').fill('kept phrase');await p.evaluate(()=>window.emitState());await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));await p.waitForFunction(()=>document.querySelector('[name=source]')?.value==='unsaved phrase');
 if(await p.locator('[name=target]').inputValue()!=='kept phrase')throw Error('Lost dictionary draft');
 if(await p.evaluate(()=>document.activeElement?.getAttribute('name'))!=='target')throw Error('Lost form focus');
 await p.getByRole('button',{name:'History',exact:true}).click();await p.locator('#search').fill('alpha beta');await p.locator('#search').evaluate(el=>el.setSelectionRange(3,3));await p.keyboard.type('x');
 if(await p.locator('#search').inputValue()!=='alpxha beta'||await p.locator('#search').evaluate(el=>el.selectionStart)!==4)throw Error('Search caret moved');

 await p.getByRole('button',{name:'Settings',exact:true}).click();await p.locator('[name=appearance]').selectOption('light');await p.evaluate(()=>window.failSave=true);await p.locator('#settings-form button[type=submit]').click();await p.getByText(/Synthetic save failure/).waitFor();if(await p.locator('[name=appearance]').inputValue()!=='light')throw Error('Lost settings draft on error');if(await p.evaluate(()=>document.activeElement?.id)!=='save-settings')throw Error('Lost submit button focus');await p.evaluate(()=>window.failSave=false);await p.locator('#settings-form button[type=submit]').click();
 await p.getByRole('button',{name:'Dashboard',exact:true}).click();await capture({path:out+'/portable-dashboard-light.png',fullPage:true});
 await p.getByRole('button',{name:'Start recording'}).first().click();await p.getByRole('button',{name:'Finish recording'}).first().click();await capture({path:out+'/portable-recovery-light.png',fullPage:true});
 await p.locator('[data-action=copy-recovery]').click();
 await p.reload();await p.getByRole('heading',{name:'Make room for your voice.'}).waitFor();await p.getByRole('button',{name:'Dictionary',exact:true}).click();await p.getByRole('heading',{name:'Dictionary',exact:true}).waitFor();if(await p.getByRole('heading',{name:'Make room for your voice.'}).count())throw Error('Onboarding navigation did not leave setup');
 if(errors.length)throw Error(errors.join('\n'));console.log('UI checks passed: responsive download, themes, setup, dictionary, settings, record and recovery (mock IPC; synthetic data).');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
