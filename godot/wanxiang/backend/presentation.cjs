'use strict';
// Presentation events have identity and birth time. Repeated snapshots never restart them.
module.exports=function({Battle,FACTIONS}){
 const raw={};for(const key of ['cast','attack','hit','effect','later','zone','shield','heal','float','mark'])raw[key]=Battle.prototype[key];
 const context=(b,src,fn,skill=undefined)=>{const old=b.visualSource,oldSkill=b.visualSkillToken;b.visualSource=src;if(skill!==undefined)b.visualSkillToken=skill;try{return fn()}finally{b.visualSource=old;b.visualSkillToken=oldSkill}};
 Battle.prototype.float=function(u,text,color){if(this.suppressNumeric&&/^\d+$/.test(String(text)))return;raw.float.call(this,u,text,color)};
 Battle.prototype.effect=function(type,a,b,color,extra={}){
  raw.effect.call(this,type,a,b,color,extra);
  const f=this.fx.at(-1),src=this.visualSource||a;
  Object.assign(f,{id:++this.visualSerial||(this.visualSerial=1),born:this.t,skillToken:this.visualSkillToken??null,sourceUid:src?.uid||null,anchorUid:a?.uid||null,targetUid:b?.uid||a?.uid||null,sourceName:src?.d?.name||'',skillName:src?.d?.skill||'',actor:src?.id??null,team:src?.team??0,faction:src?.d?.faction||FACTIONS.find(x=>x.color===color)?.id||'math'});
  if(type==='text')f.targetUid=a?.uid||null;
 };
 Battle.prototype.later=function(delay,fn){const src=this.visualSource,skill=this.visualSkillToken;raw.later.call(this,delay,()=>context(this,src,fn,skill))};
 Battle.prototype.zone=function(src,type,point,r,duration,tick,interval=1){
  const skill=this.visualSkillToken;const z=raw.zone.call(this,src,type,point,r,duration,()=>context(this,src,tick,skill),interval);z.skillToken=skill;
  z.id=++this.zoneSerial||(this.zoneSerial=1);z.born=this.t;return z;
 };
 Battle.prototype.cast=function(u){
  if(!u||u.dead||u.summon||!u.d.cd)return;
  u.skillTimer=u.d.cd;u.skillWindupAt=this.t;u.skillSequence=(u.skillSequence||0)+1;
  let target=this.find(u.target)||this.closest(u,this.foes(u));
  const allies=this.friends(u.team),others=allies.filter(v=>v!==u);
  if([4,6,7,8,12,18,24,28,31,37,43].includes(u.id))target=u;
  if([20,48].includes(u.id))target=this.closest(u,others)||u;
  if([26,32,35,39,52].includes(u.id))target=this.lowest(u.id===52?this.near(u,allies,3):allies)[0]||u;
  if(u.id===17)target=[...allies].sort((a,b)=>b.recent.reduce((n,v)=>n+v.damage,0)-a.recent.reduce((n,v)=>n+v.damage,0))[0]||u;
  u.aimUid=target?.uid||null;
  const delay=[13,44,62].includes(u.id)?.12:.32,skill=u.uid+':'+u.skillSequence;
  context(this,u,()=>this.effect('charge',u,target,undefined,{life:delay,skill:true}),skill);
  u.cast={end:this.t+delay,hits:0,fn:()=>{
   if(u.dead||this.has(u,'silence'))return;
   context(this,u,()=>raw.cast.call(this,u),skill);
   if(u.cast){const fn=u.cast.fn;u.cast.fn=(c)=>{u.skillReleaseAt=this.t;context(this,u,()=>fn(c),skill)}}
   else u.skillReleaseAt=this.t;
  }};
 };
 Battle.prototype.attack=function(u,v){
  if(!v||v.dead)return;u.attackWindupAt=this.t;u.aimUid=v.uid;u.atkTimer=99;
  this.later(.18,()=>{if(u.dead||u.cast||this.has(u,'stun')||v.dead){u.atkTimer=.15;return}
   context(this,u,()=>raw.attack.call(this,u,v),null);u.atkTimer=Math.max(.15,u.atkTimer-.18);
  });
 };
 Battle.prototype.hit=function(src,u,amount,o={}){
  if(!u||u.dead||u.hp<=0)return 0;
  if(src&&((src.range>2&&o.skill===false)||([23,27,56].includes(src.id)&&o.skill!==false))&&!o.secondary&&!o.deferred){this.later(.27,()=>this.hit(src,u,amount,{...o,deferred:true}));return 0}
  return context(this,src||this.visualSource,()=>{
   const oldSuppress=this.suppressNumeric;this.suppressNumeric=true;
   let result;try{result=raw.hit.call(this,src,u,amount,o)}finally{this.suppressNumeric=oldSuppress}
   return result;
  });
 };
 Battle.prototype.damagePresented=function(src,u,damage,absorbed,o){
  if(damage>.5)this.effect('number',u,null,undefined,{life:.95,amount:Math.round(damage),numberType:o.magic?'magic':'physical',skill:o.skill});
  if(absorbed>.5)this.effect('number',u,null,undefined,{life:.8,amount:Math.round(absorbed),numberType:'absorbed'});
  if(damage+absorbed>0){u.hitFromX=src?.x??u.x;u.hitFromY=src?.y??u.y;this.effect('contact',u,null,undefined,{life:.3,amount:Math.round(damage+absorbed),skill:o.skill})}
 };
 Battle.prototype.mark=function(src,u,type,spread=false){
  const previous=u?Object.keys(u.marks).filter(k=>u.marks[k]>this.t):[],reaction=u?.reactAt;
  context(this,src,()=>raw.mark.call(this,src,u,type,spread));
  if(u&&u.reactAt!==reaction&&u.reactAt===this.t){const labels={acid:'酸',charge:'电',heat:'热'};context(this,src,()=>this.effect('reaction',u,null,undefined,{life:1.0,text:labels[previous.find(k=>k!==type)]+' + '+labels[type]+' → 反应'}))}
 };
 Battle.prototype.shield=function(src,u,amount,secondary=false){return context(this,src||this.visualSource,()=>raw.shield.call(this,src,u,amount,secondary))};
 Battle.prototype.heal=function(src,u,amount,secondary=false){
  if(!u)return;const before=u.hp;
  context(this,src||this.visualSource,()=>raw.heal.call(this,src,u,amount,secondary));
  if(src&&u.hp-before>10)context(this,src,()=>this.effect('heal',u,null,undefined,{life:.65,amount:Math.round(u.hp-before)}));
 };
};
