'use strict';
// Playful props are tied to actual combat milestones, not decorative damage.
module.exports=function({Battle}){
 Battle.prototype.comicSkill=function(u,{target,allies,others,enemies,p,col,D,S,H,A}){
  const cue=(type,a,b,life,extra={})=>this.effect(type,a,b,col,{life,...extra});
  if(![3,10,19,29,39,40,41,43,51].includes(u.id)&&u.d.prop)cue('gag_signature',u,null,.95,{prop:u.d.prop,caption:u.d.caption,joke:u.d.joke});
  switch(u.id){
   case 3:{
    let n=this.random()*u.dice.reduce((a,b)=>a+b,0),pick=0;
    while(n>u.dice[pick]&&pick<2)n-=u.dice[pick++];
    u.dice=u.dice.map((v,i)=>i===pick?1:v+1);
    cue('gag_dice',u,pick===0?target:u,.6,{outcome:pick});
    this.later(.6,()=>{
     if(pick===0){if(target.dead)return;D(target,180);cue('gag_land',target,null,.5,{prop:'dice',joke:'数学说：这次算你的！'})}
     else if(pick===1){this.near(u,this.friends(u.team),2).forEach(v=>S(v,140));cue('gag_land',u,null,.5,{prop:'dice',joke:'今天主打一个稳。'})}
     else{this.near(target,this.foes(u),1.5).forEach(v=>this.control(v,'slow',2,u.uid));cue('gag_land',target,null,.5,{prop:'dice',joke:'先冷静两秒。'})}
    });return true;
   }
   case 10:{
    cue('gag_magnet',u,target,.7);
    this.later(.7,()=>{if(target.dead)return;this.push(target,u,1,true);D(target,65);this.control(target,'stun',.35,u.uid);this.buff(target,'magnetic',4,20*p,u.uid);cue('gag_land',target,null,.55,{prop:'car',joke:'谁把车停这儿了？'});});return true;
   }
   case 19:{
    cue('gag_soda',u,target,.45);
    this.later(.45,()=>{const center={x:target.x,y:target.y};cue('gag_fizz',center,null,.8,{joke:'压力小了，场面大了。'});this.zone(u,'acid',center,1.5,2,()=>{for(const v of this.near(center,this.foes(u),1.5)){D(v,50);this.mark(u,v,'acid')}});});return true;
   }
   case 29:{
    const recipient=this.farthest(u,others);if(!recipient)return true;
    cue('gag_delivery',u,recipient,.65);
    this.later(.65,()=>{if(recipient.dead)return;S(recipient,100);this.buff(u,'courier',5,1,recipient.uid);cue('link',u,recipient,1.2);cue('gag_land',recipient,null,.55,{prop:'parcel',joke:'补给到了，记得签收！'})});return true;
   }
   case 39:{
    const pair=this.lowest(allies,2);if(pair.length!==2)return true;
    cue('gag_romance',pair[0],pair[1],.6);
    this.later(.6,()=>{if(pair.some(v=>v.dead))return;this.buff(pair[0],'couplet',4,2,pair[1].uid);this.buff(pair[1],'couplet',4,2,pair[0].uid);for(const v of pair)this.shield(u,v,60*p,true);cue('gag_letters',pair[0],pair[1],4,{joke:'台词可以分开，护盾必须共享。'})});return true;
   }
   case 40:{
    for(let i=0;i<3;i++)this.later(i*.42,()=>{
     if(u.dead||this.has(u,'stun')||this.has(u,'silence'))return;
     cue('gag_house',u,target,.28,{variant:i});
     this.later(.28,()=>{if(u.dead||this.has(u,'stun')||this.has(u,'silence'))return;A(target,i===2?1.8:1.2,[80,110,150][i]);cue('gag_land',target,null,.38,{prop:['straw','wood','brick'][i],joke:['草房：先凑合。','木房：再加固。','砖房：这下结实了！'][i]})});
    });return true;
   }
   case 41:{cue('gag_midnight',u,target,3,{joke:'先别笑，钟还没敲完。'});this.later(3,()=>{if(!target.dead&&this.has(target,'foreshadow'))cue('gag_land',target,null,.55,{prop:'pumpkin',joke:'午夜到了，伏笔收回！'})});return false;}
   case 43:cue('gag_poem',u,null,.9,{joke:'把好天气写进下一发。'});return false;
   case 51:{
    cue('gag_gavel',u,target,.55);
    u.cast={end:this.t+.55,hits:0,fn:()=>{if(target.dead)return;const enough=target.evidence>=(this.counts[u.team].law>=6?2:3);D(target,260+(enough?140:0));let executed=false;if(target.hp>0&&target.hp/target.maxhp<.12&&target.shield<=0){target.hp=0;executed=true;}cue('gag_land',target,null,.65,{prop:'gavel',joke:executed?'散会！':'先讲证据，再敲桌子。'});}};return true;
  }
  }
  return false;
 };
 Battle.prototype.comicAttack=function(u,target,index){
  if(u.id===1&&u.attackCount%5===0)this.effect('gag_signature',u,target,'#72d8db',{life:.85,prop:'dice',caption:'满五发货',joke:u.d.joke});
  if(u.id===43&&index)this.effect('gag_verse',u,target,'#c9a7ef',{life:.5,variant:3-index,joke:['夏日：慢下来。','风暴：一起摇摆。','诗行：我记住你了。'][3-index]});
 };
};
