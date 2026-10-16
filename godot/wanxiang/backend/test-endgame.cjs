'use strict';
const assert=require('node:assert/strict');
const {Session,Core}=require('./server.cjs');
const s=new Session(),g=s.game;g.gold=1000;
while(g.level<10)assert.equal(g.buyXp(),null);
const gold=g.gold;assert(g.buyXp());assert.equal(g.gold,gold);assert.equal(g.level,10);
g.units=Array.from({length:11},(_,i)=>({id:i,uid:'cap'+i,star:1,c:null,r:null}));g.fillOpen();
assert.equal(g.deployed().length,10);assert.equal(g.bench().length,1);
const spare=g.bench()[0],front=g.deployed()[0],cell={c:front.c,r:front.r};
assert.equal(g.move(spare.uid,cell.c,cell.r),null);assert.equal(front.c,null);assert.equal(g.deployed().length,10);
const empty=g.freePlace('guard');assert(g.move(front.uid,empty.c,empty.r),'cannot deploy eleventh unit into empty cell');
for(const odds of Object.values(Core.ODDS))assert.equal(odds.reduce((a,b)=>a+b),100);
for(const f of Core.FACTIONS){const cards=Core.CATALOG.filter(d=>d.faction===f.id);assert.equal(cards.length,9);assert.deepEqual([...new Set(cards.map(d=>d.cost))].sort(),[1,2,3,4,5]);assert(cards.every(d=>d.quality&&d.qualityColor));}
const exhausted=new Session().game;exhausted.level=3;exhausted.shop=[];exhausted.pool=Core.CATALOG.map(d=>d.cost===5?1:0);exhausted.refresh(true);assert(exhausted.shop.every(id=>id===null),'depleted low-tier pools cannot unlock legendary cards early');
const late=new Session().game;late.round=28;for(const ai of late.ais){ai.gold=500;ai.level=9;ai.xp=0;late.planAI(ai);assert.equal(ai.level,10);assert(ai.deployed().length<=10);}
function arena(id){
 const b=new Core.Battle([{id,uid:'hero',star:1,c:2,r:5},{id:0,uid:'ally',star:1,c:1,r:5},{id:7,uid:'fallen',star:2,c:4,r:5}], [{id:45,uid:'enemy',star:1,c:2,r:2},{id:28,uid:'enemy2',star:1,c:3,r:2}],{random:()=>.2});
 for(const u of b.units){u.maxhp=u.hp=10000;u.atkTimer=999;u.skillTimer=999;u.range=99;u.node=false;}
 return b;
}
function advance(b,duration){const end=b.t+duration;while(b.t<end&&!b.done)b.step(.01)}
for(const id of [8,17,26,35,44,53]){
 let b=arena(id),h=b.find('hero'),e=b.find('enemy');b.cast(h);advance(b,.5);assert(b.fx.some(f=>f.type==='legendary_charge'));assert.equal(e.hp,10000);b.control(h,'stun',2,e.uid);advance(b,1.5);assert(!b.fx.some(f=>f.type==='legendary_release'));assert.equal(e.hp,10000);
 b=arena(id);h=b.find('hero');e=b.find('enemy');const a=b.find('ally');
 if(id===17){a.hp=5000;a.recent=[{t:0,damage:1500}];b.buff(a,'root',4);}
 if(id===35){const f=b.find('fallen');f.hp=0;f.dead=true;}
 b.cast(h);advance(b,1.4);
 assert(b.fx.some(f=>f.type==='legendary_release'),'release '+id);
 if(id===8){assert(e.hp<10000);assert(b.has(e,'root'));assert(a.shield>0);}
 if(id===17){assert(a.hp>6000);assert(!b.has(a,'root'));assert(b.has(e,'stun'));}
 if(id===26){assert(h.shield>0);assert(b.zones.some(z=>z.type==='reactor'));advance(b,2);assert(e.hp<9300,`reactor dealt ${10000-e.hp}`);assert(Object.keys(e.marks).length>=2);}
 if(id===35){assert(b.find('fallen').revived);assert.equal(b.find('fallen').hp,4000);assert.equal(b.units.filter(u=>u.summon).length,2);const f=b.find('fallen');f.hp=0;f.dead=true;b.cast(h);advance(b,1.4);assert(!b.find('fallen'),'only one resurrection per team');assert.equal(b.units.filter(u=>u.summon).length,2);}
 if(id===44){advance(b,.65);assert(Math.abs((10000-e.hp)-405*100/(100+e.mr))<.01,'three real damage pulses');assert(b.has(e,'bookbound'));b.cleanse(e);assert(!b.has(e,'bookbound'));}
 if(id===53){const court=b.zones.find(z=>z.type==='court');assert(court.enemyOnly);a.x=court.x;a.y=court.y;b.cast(a);advance(b,.4);assert(!b.has(a,'silence'));const before=e.hp;b.cast(e);advance(b,.4);assert(b.has(e,'silence'));assert(e.hp<before);assert.equal(e.cast,null);}
}
console.log('PASS: 10-population cap and replacement; complete rarity tiers; six legendary releases, pre-release interruption, rewind, reactor, one resurrection, book cleanse, enemy-only interrupting court');
