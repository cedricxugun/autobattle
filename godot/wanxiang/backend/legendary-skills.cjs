'use strict';
module.exports=function({Battle}){
 Battle.prototype.legendaryFocus=function(u){
  if(u.id===35)return u;
  const enemies=this.foes(u);
  return [...enemies].sort((a,b)=>{
   const score=v=>this.near(v,enemies,2.6).reduce((n,x)=>n+1+x.d.cost*.10,0);
   return score(b)-score(a)||this.dist(u,a)-this.dist(u,b);
  })[0]||u;
 };
 Battle.prototype.legendarySkill=function(u,{p,col,D,S,H}){
  if(![8,17,26,35,44,53].includes(u.id))return false;
  const focus=this.legendaryFocus(u),center={x:focus.x,y:focus.y};
  const windup=u.id===44?1.2:1.0;
  u.aimUid=focus.uid;
  this.effect('legendary_charge',u,focus,col,{life:windup,r:u.id===17?2.8:2.6,legend:u.id});
  u.cast={end:this.t+windup,hits:0,fn:()=>{
   this.effect('legendary_release',u,center,col,{life:1.8,r:u.id===17?2.8:2.6,legend:u.id});
   this.log('传说觉醒 · '+u.d.name+'：'+u.d.skill);
   const friends=()=>this.friends(u.team),foes=()=>this.foes(u);
   if(u.id===8){
    for(const v of this.near(center,foes(),2.6)){D(v,360);this.control(v,'root',1.6,u.uid)}
    const mode=({growth:'grow',heal:'cleanse'})[this.options.axiom]||this.options.axiom||'shield';
    for(const v of friends()){
     if(mode==='cleanse'){this.cleanse(v);H(v,220)}
     else if(mode==='grow')this.buff(v,'skillUp',6,.35);
     else S(v,220);
    }
   }else if(u.id===17){
    for(const v of friends()){
     const recent=v.recent.filter(x=>x.t>this.t-2).reduce((n,x)=>n+x.damage,0);
     this.cleanse(v);H(v,Math.min(v.maxhp*.45/p,100+recent*.8/p));
    }
    for(const v of this.near(center,foes(),2.8))this.control(v,'stun',1.3+u.star*.3,u.uid);
   }else if(u.id===26){
    S(u,u.maxhp*.30/p);
    this.zone(u,'reactor',center,2.6,4,()=>{
     const index=Math.floor(this.t)%3;
     for(const v of this.near(center,foes(),2.6)){
      D(v,70+v.maxhp*.035/p);this.mark(u,v,['acid','charge','heat'][index]);
     }
    });
   }else if(u.id===35){
    this.arkRevived=this.arkRevived||[false,false];
    const fallen=this.units.filter(v=>v.team===u.team&&v.dead&&!v.summon&&v!==u).sort((a,b)=>b.d.cost*b.star-a.d.cost*a.star)[0];
    if(fallen&&!this.arkRevived[u.team]){
     const place=this.emptyNear(u.x,u.y,fallen);
     if(place){
      this.arkRevived[u.team]=true;
      fallen.x=place.x;fallen.y=place.y;fallen.dead=false;fallen.hp=fallen.maxhp*.40;
      fallen.shield=0;fallen.buffs={};fallen.marks={};fallen.cast=null;fallen.step=null;fallen.target=null;
      fallen.skillTimer=Math.max(2,fallen.d.cd*.6);fallen.atkTimer=.6;fallen.recent=[];fallen.revived=true;
      this.effect('legendary_revive',fallen,null,col,{life:1.4,legend:35});
     }
    }else this.lowest(friends(),3).forEach(v=>S(v,200));
    const before=new Set(this.units.map(v=>v.uid));
    const existing=friends().filter(v=>v.owner===u.uid&&v.kind==='ancestor').length;
    this.summon(u,'ancestor',Math.max(0,2-existing));
    for(const v of this.units.filter(v=>!before.has(v.uid))){v.maxhp=v.hp=u.maxhp*.30;v.atk=u.atk*.55;v.expires=this.t+8;}
   }else if(u.id===44){
    const authors=[...this.castHistory[u.team]].filter(id=>id>=36&&id<45).length;
    for(let act=0;act<3;act++)this.later(act*.32,()=>{
     if(u.dead||this.has(u,'stun')||this.has(u,'silence'))return;
     this.effect('legendary_wave',u,center,col,{life:.6,r:2.6,legend:44,act});
     for(const v of this.near(center,foes(),2.6)){
      D(v,120+Math.min(75,authors*15));
      if(act===2){this.control(v,'stun',1.1,u.uid);if(this.has(v,'stun'))this.buff(v,'bookbound',Math.min(1.1,v.buffs.stun.until-this.t));}
     }
    });
   }else if(u.id===53){
    for(const v of this.near(center,foes(),2.6)){D(v,300+(v.evidence>=3?180:0));this.control(v,'root',1.2,u.uid)}
    this.near(center,friends(),2.6).forEach(v=>S(v,200));
    const court=this.zone(u,'court',center,2.6,6,()=>{});
    court.enemyOnly=true;court.silenceDuration=2;court.punishPower=140*p;
   }
  }};
  return true;
 };
};
