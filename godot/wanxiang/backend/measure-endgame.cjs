const {Core}=require('./server.cjs');
function rng(seed){return()=>{seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return(seed>>>0)/4294967296}}
function roster(ids,team){const occupied=[];for(let i=0;i<ids.length;i++){const id=ids[i],role=Core.definition(id).role,front=['guard','fighter'].includes(role),rows=team===0?(front?[5,6,7]:[7,6,5]):(front?[2,1,0]:[0,1,2]);let pos;for(const r of rows){for(const c of [2,3,1,4,0,5])if(!occupied.some(u=>u.c===c&&u.r===r)){pos={c,r};break}if(pos)break}occupied.push({id,uid:team+':'+i,star:Core.definition(id).cost===5?1:2,...pos})}return occupied}
const results=[];
for(const legend of [8,17,26,35,44,53]){let wins=[0,0],flips=0,losses=0,damage=[0,0],casts=0;
 for(let n=0;n<18;n++){const f=Math.floor(legend/9)*9;const own=[f,f+1,f+2,f+3,f+4,0,27,45,36];const ef=(n%6)*9;const enemy=roster([ef,ef+1,ef+2,ef+3,ef+4,ef+5,ef+6,ef+7,18,9],1);let outcome=[];
 for(let variant=0;variant<2;variant++){const b=new Core.Battle(roster([...own,variant?legend:f+6],0),enemy,{random:rng(800+n),rules:['cast','cast']});let released=false;for(let k=0;k<1201&&!b.done;k++){b.step(.05);if(b.fx.some(e=>e.type==='legendary_release'&&e.sourceUid==='0:9'))released=true;}const win=b.winner===0;outcome.push(win);wins[variant]+=win;damage[variant]+=b.units.find(u=>u.uid==='0:9').damage;if(variant&&released)casts++;}
 if(!outcome[0]&&outcome[1])flips++;if(outcome[0]&&!outcome[1])losses++;
 }results.push({legend,name:Core.definition(legend).name,matchups:18,wins,upgradesToWin:flips,changedToLoss:losses,averageDamage:damage.map(n=>Math.round(n/18)),released:casts});}
console.log(JSON.stringify(results,null,2));
