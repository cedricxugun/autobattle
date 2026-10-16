from pathlib import Path
import shutil, zipfile

base=Path(__file__).resolve().parent
workspace=base.parent
source=base/'wanxiang'
destination=workspace/'output'/'万象棋局-3D庭院-0.4'
destination.mkdir(parents=True,exist_ok=True)
game=destination/'game'
for path in source.rglob('*'):
    if not path.is_file(): continue
    relative=path.relative_to(source)
    if '.godot' in relative.parts and str(relative).replace('\\','/')!='.godot/global_script_class_cache.cfg': continue
    if path.name.startswith('test') or path.suffix=='.import': continue
    target=game/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(path,target)
(destination/'runtime').mkdir(exist_ok=True)
shutil.copy2(base/'tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe',destination/'runtime/Godot.exe')
shutil.copy2(base/'WanxiangLauncher.exe',destination/'万象棋局.exe')
shutil.copy2(base/'嘉年华版本说明.txt',destination/'开始前读我.txt')
materials=destination/'制作资料';materials.mkdir(exist_ok=True)
for name in ['comic-art-prompts.json','comic-extra-prompt.txt','carnival-scene-prompt.txt','arena-v2-prompts.json','courtyard-3d-prompts.json','场景改造说明.txt','Launcher.cs']:
    shutil.copy2(base/name,materials/name)
(destination/'趣味技能剧场.cmd').write_text('@echo off\r\nchcp 65001 >nul\r\nstart "" "%~dp0万象棋局.exe" --theater\r\n',encoding='utf-8')
archive=workspace/'output'/'万象棋局-3D庭院-0.4-Windows64.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as package:
    for path in destination.rglob('*'):
        if path.is_file():package.write(path,path.relative_to(destination.parent))
print(f'Portable folder: {destination}')
print(f'Archive: {archive} ({archive.stat().st_size/1024/1024:.1f} MiB)')
