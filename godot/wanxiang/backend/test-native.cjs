'use strict';
const assert=require('node:assert/strict');
const {Session,NativeLeague,Core}=require('./server.cjs');
const {CATALOG,STOCK,PVE_ROUNDS,Battle}=Core;
function invariant(g){
  for(const d of CATALOG){
    let held=g.pool[d.id];
    assert(held>=0,`negative pool ${d.name}`);
    for(const p of g.players()){
      held+=p.units.filter(u=>u.id===d.id).reduce((n,u)=>n+3**(u.star-1),0);
      held+=p.shop.filter(id=>id===d.id).length;
    }
    assert.equal(held,STOCK[d.cost],`pool conservation ${d.name}`);
  }
  for(const p of g.players()){
    const cells=p.deployed().map(u=>`${u.c},${u.r}`);
    assert.equal(new Set(cells).size,cells.length,`occupied cells ${p.name}`);
  }
}
// Controlled shop offers still reserve real pool copies.
function offer(s,id){const g=s.game;for(const old of g.shop)if(old!=null)g.pool[old]++;assert(g.pool[id]>0);g.pool[id]--;g.shop=[id,null,null,null,null];return s.command('buy',{slot:0})}
const s=new Session();s.game.gold=100;
for(const id of s.game.shop)if(id!=null)s.game.pool[id]++;
s.game.shop=[];
for(let n=0;n<9;n++)offer(s,0);
assert.equal(s.game.units.length,1);assert.equal(s.game.units[0].star,3);
assert.equal(s.game.units[0].uid,'p1','merges retain deployed identity');invariant(s.game);
const uid=s.game.units[0].uid;
s.command('inspect',{uid,player:'you'});assert.equal(s.snapshot().detail.star,3);
s.command('move',{uid,c:null,r:null});offer(s,1);
assert.equal(s.game.units.find(u=>u.uid===uid).c,null,'intentional bench persists after buy');
const target=s.game.units.find(u=>u.id===1),position=[target.c,target.r];
s.command('move',{uid,c:target.c,r:target.r});
assert.equal(target.c,null,'bench-board replacement');
assert.deepEqual([s.game.units.find(u=>u.uid===uid).c,s.game.units.find(u=>u.uid===uid).r],position);
s.game.bag=['blade'];s.command('equip',{uid,index:0});assert.equal(s.game.units[0].item,'blade');
s.command('unequip',{uid});assert(s.game.bag.includes('blade'));
invariant(s.game);
s.command('start');assert.equal(s.boards.size,8);
s.tick(.1);const ownTime=s.boards.get('you').t;
s.command('watch',{player:'ai0'});assert.equal(s.snapshot().watching,'ai0');s.tick(.1);
assert(s.boards.get('you').t>ownTime,'spectating must not stop own battle');
for(let i=0;i<1400&&s.game.phase==='battle';i++)s.tick(.05);
assert.equal(s.game.pendingLoot.length,3);const round=s.game.round;
s.command('next');assert.equal(s.game.round,round,'unclaimed loot blocks next');
s.command('loot',{item:s.game.pendingLoot[0]});s.command('next');assert.equal(s.game.round,round+1);
invariant(s.game);
const restored=new NativeLeague(JSON.parse(JSON.stringify(s.game)));
assert(restored.ais.every(a=>a.pool===restored.pool));invariant(restored);
const totals={};
for(const difficulty of ['easy','hard','torment']){
 const session=new Session();session.command('new',{difficulty});const g=session.game;
 g.preferences=['math','chemistry'];g.intent='automated player';g.gold=80;
 let rounds=0;
 for(let i=0;i<25;i++){
  g.planAI(g);invariant(g);
  if(g.roundType==='pvp'){
   assert.equal(new Set(g.matches.map(m=>m.owner)).size,g.living().length);
   assert.equal(new Set(g.matches.map(m=>m.opponent)).size,g.living().length);
   assert(g.matches.every(m=>m.owner!==m.opponent));
  }
  session.command('start');
  for(let t=0;t<1400&&g.phase==='battle';t++)session.tick(.05);
  assert.notEqual(g.phase,'battle');invariant(g);rounds++;
  if(g.pendingLoot.length)session.command('loot',{item:g.pendingLoot[0]});
  if(g.phase!=='result')break;
  session.command('next');invariant(g);
 }
 totals[difficulty]=rounds;
}
for(const round of Object.keys(PVE_ROUNDS)){
 const g=new NativeLeague();g.round=Number(round);g.prepareRound();invariant(g);
 assert(g.matches.every(m=>m.opponent==='wild'));
}
console.log(JSON.stringify({threeStarMerge:'passed',benchSwap:'passed',equipment:'passed',eightConcurrentBoards:'passed',spectating:'passed',lootGuard:'passed',saveRestore:'passed',sharedPool:'passed',leagueRounds:totals}));
