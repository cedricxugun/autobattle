const assert=require('node:assert/strict');
const {Session,Core}=require('./server.cjs');
const {Battle}=Core;
for(let id=0;id<63;id++){
 const s=new Session(),before=JSON.stringify(s.game);
 s.command('preview_skill',{id});
 const events=new Map();let sawCast=false;
 for(let i=0;i<320&&!s.demoBattle.done;i++){
  s.tick(.05);
  const b=s.snapshot().board;
  for(const f of b.effects){
   assert(Number.isInteger(f.id)&&Number.isFinite(f.born));
   if(events.has(f.id))assert.equal(events.get(f.id),f.born,'event birth must never reset');
   events.set(f.id,f.born);
   if(f.type==='cast'&&f.sourceUid==='demoMain')sawCast=true;
   if(id===0&&f.type==='contact'&&f.sourceUid==='demoMain')assert.equal(f.skillToken,null,'triangle protection must not claim subsequent basic attacks');
   if(f.type==='contact')assert(f.targetUid&&f.sourceUid,'damage knows source and target');
  }
  for(const z of b.zones)assert(Number.isFinite(z.born)&&Number.isInteger(z.id));
 }
 if(Core.definition(id).cd>0)assert(sawCast,'skill release '+id);
 s.command('buy',{slot:0});assert.equal(JSON.stringify(s.game),before,'demo must not mutate league');
 s.command('close_preview');assert.equal(JSON.stringify(s.game),before);
}
const b=new Battle([{id:0,uid:'a',star:1,c:2,r:5}],[{id:1,uid:'b',star:1,c:1,r:2}]);
const src=b.units[0],dst=b.units[1];dst.def=50;dst.shield=20;
b.hit(src,dst,150,{magic:false,skill:false,secondary:true});
const nums=b.fx.filter(f=>f.type==='number');
assert.equal(nums.find(f=>f.numberType==='physical').amount,80);
assert.equal(nums.find(f=>f.numberType==='absorbed').amount,20);
assert(!b.fx.some(f=>f.type==='text'&&/^\d+$/.test(f.text)),'no duplicate legacy damage numbers');
console.log('PASS: all 63 isolated skill demonstrations; immutable event birth; source/target provenance; field metadata; league isolation; exact health/shield damage text');
const rehearsal=new Session(),leagueBefore=JSON.stringify(rehearsal.game);
rehearsal.command('preview_battle');
assert.equal(rehearsal.demoBattle.units.length,16);
const key=rehearsal.snapshot().matchKey;
rehearsal.command('speed',{value:.5});rehearsal.tick(1);
assert.equal(rehearsal.demoBattle.t,.5,'half-speed rehearsal');
rehearsal.command('replay_preview');
assert.equal(rehearsal.demoBattle.t,0);
assert.notEqual(rehearsal.snapshot().matchKey,key,'replay creates fresh presentation context');
assert.equal(JSON.stringify(rehearsal.game),leagueBefore);
console.log('PASS: 16-unit rehearsal, half-speed, replay identity, preserved league');
