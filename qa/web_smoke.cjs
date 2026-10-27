const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'..');
const work=path.join(root,'.qa-cache','web-browser');
fs.mkdirSync(path.join(work,'temp'),{recursive:true});
process.env.TEMP=path.join(work,'temp');process.env.TMP=process.env.TEMP;
const {chromium}=require('playwright');
const local=process.argv.includes('--file');
const output=path.join(work,local?'file':'http');fs.mkdirSync(output,{recursive:true});
const entry=local?pathToFileURL(path.join(root,'index.html')).href:'http://127.0.0.1:8070/';
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist'],downloadsPath:path.join(work,'downloads')});
 const context=await browser.newContext({viewport:{width:1440,height:900}});
 const page=await context.newPage();const errors=[],messages=[],requests=[];
 page.on('console',m=>{messages.push(m.type()+': '+m.text());if(m.type()==='error')errors.push(m.text());});
 page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>requests.push(r.url()));
 const capture=async name=>page.screenshot({path:path.join(output,name+'.png')});
 const click=async(x,y,button='left')=>{const box=await page.locator('#canvas').boundingBox();await page.mouse.click(box.x+x*box.width/1366,box.y+y*box.height/768,{button});await page.waitForTimeout(400);};
 const readSave=()=>page.evaluate(async()=>{
  const found=[];
  for(const info of await indexedDB.databases()){
   const db=await new Promise((resolve,reject)=>{const r=indexedDB.open(info.name);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
   for(const store of db.objectStoreNames)await new Promise((resolve,reject)=>{const tx=db.transaction(store),r=tx.objectStore(store).openCursor();r.onerror=()=>reject(r.error);r.onsuccess=()=>{const c=r.result;if(!c){resolve();return;}if(String(c.key).endsWith('east_full_v2.json'))found.push({key:c.key,data:JSON.parse(new TextDecoder().decode(c.value.contents))});c.continue();};});
   db.close();
  }return found;
 });
 try{
  await page.goto(entry);await capture('landing');
  await page.getByRole('button',{name:'入境 · 开始游戏'}).click();
  await page.waitForFunction(()=>window.eastGameReady===true,null,{timeout:180000});
  await page.waitForTimeout(3000);await capture('village');
  assert.equal(await page.locator('#cover').isVisible(),false,'startup cover closes after scene is ready');
  await click(318,700);await page.keyboard.press('r');await click(700,450,'right');
  await click(318,700);await click(700,400);await click(700,400,'right');
  await click(870,645); // Pause after placing one well.
  await capture('construction');
  const box=await page.locator('#canvas').boundingBox();
  await page.mouse.move(box.x+box.width*.45,box.y+box.height*.5);
  await page.mouse.down({button:'middle'});await page.mouse.move(box.x+box.width*.5,box.y+box.height*.54,{steps:8});await page.mouse.up({button:'middle'});
  await page.mouse.wheel(0,-160);await page.waitForTimeout(750);await capture('camera');
  await click(1305,45);await capture('settings');
  await click(1215,282); // Save current progress.
  await page.waitForTimeout(2500);
  let saves=await readSave();
  assert.equal(saves.length,1,'one browser-only settlement save');
  assert.equal(saves[0].data.buildings.length,2,'initial home and one player-built well survive save');
  assert.equal(saves[0].data.buildings.filter(b=>b.type==='well').length,1,'the newly placed building is a well');
  assert.equal(saves[0].data.time_paused,true,'pause state was saved');
  const elapsed=saves[0].data.economy.elapsed;
  await page.reload();await page.getByRole('button',{name:'入境 · 开始游戏'}).click();
  await page.waitForFunction(()=>window.eastGameReady===true,null,{timeout:180000});await page.waitForTimeout(1500);
  await capture('reloaded');
  await page.getByRole('button',{name:'操作说明',exact:true}).click();
  await page.waitForTimeout(2000);await page.getByRole('button',{name:'知道了',exact:true}).click();
  saves=await readSave();assert.equal(saves[0].data.economy.elapsed,elapsed,'reload restores paused time exactly');
  assert.equal(saves[0].data.buildings.filter(b=>b.type==='well').length,1,'the built well remains after reload and resave');
  await page.setViewportSize({width:1100,height:750});await page.waitForTimeout(1000);await capture('resized');
  assert.equal(errors.length,0,'no browser/resource/Godot errors: '+errors.join('\n'));
  assert.equal(requests.some(url=>/^https?:/.test(url)&&!url.startsWith('http://127.0.0.1:8070/')),false,'no external requests');
  if(!local)assert.equal(requests.some(url=>url.includes('local-data.js')),false,'HTTP mode does not load duplicate offline bundle');
  fs.writeFileSync(path.join(output,'report.json'),JSON.stringify({ok:true,local,elapsed,saveKey:saves[0].key,errors,requests},null,2));
  console.log('WEB_SMOKE_OK '+(local?'file':'http'));
 }catch(e){await capture('failure').catch(()=>{});fs.writeFileSync(path.join(output,'failure.txt'),String(e)+'\n'+errors.join('\n'));throw e;}
 finally{fs.writeFileSync(path.join(output,'console.log'),messages.join('\n'));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
