'use strict';
const assert=require('node:assert/strict');
const {Core,Session}=require('./server.cjs');
function arena(id,random=()=>.1){
 const b=new Core.Battle([{id,uid:'hero',star:1,c:2,r:5},{id:0,uid:'allyA',star:1,c:1,r:6},{id:7,uid:'allyB',star:1,c:4,r:7}],[{id:45,uid:'enemy',star:1,c:2,r:2},{id:28,uid:'enemy2',star:1,c:3,r:2}],{random,rules:['cast','cast']});
 for(const u of b.units){u.maxhp=u.hp=10000;u.atkTimer=999;u.skillTimer=999}
 const hero=b.units[0];hero.target='enemy';b.cast(hero);
 return b;
}
function advance(b,time){while(b.t+1e-6<time&&!b.done)b.step(.01)}
let b=arena(10);advance(b,.7);assert.equal(b.find('enemy').hp,10000,'car cannot damage before landing');advance(b,1.1);assert(b.find('enemy').hp<10000);assert(b.has(b.find('enemy'),'magnetic'));assert(b.fx.some(f=>f.type==='gag_land'&&f.prop==='car'));
b=arena(3);advance(b,.7);assert.equal(b.find('enemy').hp,10000);advance(b,1.0);assert(b.find('enemy').hp<10000,'dice resolves at reveal, without extra projectile delay');
b=arena(19);advance(b,.9);assert.equal(b.zones.length,1);const center={x:b.zones[0].x,y:b.zones[0].y};b.find('enemy').x=5;b.find('enemy').y=7;const before=b.find('enemy').hp;advance(b,2);assert.equal(b.find('enemy').hp,before,'acid remains at displayed landing zone');assert.equal(b.zones[0].x,center.x);
b=arena(29);advance(b,.7);assert.equal(b.find('allyB').shield,0);advance(b,1.1);assert(b.find('allyB').shield>0);assert(b.has(b.find('hero'),'courier'));
b=arena(39);advance(b,1.1);const pair=b.units.filter(u=>b.has(u,'couplet'));assert.equal(pair.length,2);assert(pair.every(u=>u.shield>0));const beforeLink=pair[1].shield;b.shield(b.units[2],pair[0],100);assert(pair[1].shield>beforeLink,'love letters represent real shield propagation');
b=arena(40);const phases=new Set();for(let i=0;i<160;i++){b.step(.01);for(const f of b.fx)if(f.type==='gag_land')phases.add(f.prop)}assert.deepEqual([...phases].sort(),['brick','straw','wood']);
b=arena(51);advance(b,.4);b.control(b.find('hero'),'stun',1,'enemy');advance(b,1.2);assert.equal(b.find('enemy').hp,10000,'interrupted gavel never deals fake impact damage');assert(!b.fx.some(f=>f.type==='gag_land'&&f.prop==='gavel'));
b=arena(41);advance(b,.5);b.cleanse(b.find('enemy'));advance(b,3.5);assert.equal(b.find('enemy').hp,10000,'cleansing midnight removes the delayed hit');assert(!b.fx.some(f=>f.type==='gag_land'&&f.prop==='pumpkin'));
for(const d of Core.CATALOG){assert(d.joke&&d.fact&&d.concept&&d.prop,'complete personality and concept '+d.id)}
console.log('PASS: landing-aligned car/dice/delivery, fixed soda region, real shared shields, three house stages, interruptible gavel, 54 personality/knowledge entries');
const fresh=new Session();fresh.command('new',{difficulty:'easy',starter:'carnival'});
assert.deepEqual([...fresh.game.shop],[10,19,0,29,10]);
for(const d of Core.CATALOG){let count=fresh.game.pool[d.id];for(const player of fresh.game.players()){count+=player.shop.filter(id=>id===d.id).length;count+=player.units.filter(u=>u.id===d.id).reduce((n,u)=>n+3**(u.star-1),0)}assert.equal(count,Core.STOCK[d.cost]);}
for(const slot of [0,1,2])fresh.command('buy',{slot});fresh.command('start');
for(let n=0;n<1400&&fresh.game.phase==='battle';n++)fresh.tick(.05);
assert(fresh.game.lastResult.won,'carnival starter clears introductory neutrals');
assert.equal(fresh.game.pendingLoot.length,3);
console.log('PASS: carnival starter pool conservation, playable opening round, equipment reward');
