const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'wanxiang/backend/catalog.js'),'utf8');
const data=vm.runInNewContext(source+';({characters:CATALOG,monsters:WILDS,factions:FACTIONS,roles:ROLES,items:ITEMS,quality:QUALITY,quality_colors:QC,star_scale:SCALE})');
fs.writeFileSync(path.join(__dirname,'wanxiang/data/catalog.json'),JSON.stringify(data,null,2));
console.log(JSON.stringify({characters:data.characters.length,monsters:data.monsters.length}));
