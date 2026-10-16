# 0.7 美术制作样板

此次从“序列帧贴片配几何特效”转向真实的骨骼角色制作流程，先完成一名角色的完整接入，避免把一张设定图当作游戏模型。

## 当前交付

- 裁决巨像：原创设定图 → Tripo网页版H3.1 → 15000面目标智能重拓扑（实际13811面）→ Mixamo人形绑定 → 六种原地动作 → GLB → Godot。
- 65个骨骼，实际动画为idle、walk、box_01、cast_a_spell、hit_to_body_01、fall。控制器在转向、施法、眩晕、受击、暂停、加速、复活和战斗结束时更新播放状态。
- 拳击采样对齐0.18秒普攻提交；施法使用原动作中明确伸手指向目标的片段，随蓄力进度播放。
- 角色有真实场景投影和PBR环境反射，手脚通过骨骼变化；商店/图鉴肖像由同一模型在Godot渲染，保留透明背景。
- 银杏盆栽：原创设定经Tripo网页生成，原始1909860三角面，本地简化到90004面/5798324字节，保留纹理。两处景物布置在战区外。
- 蓝灰石板使用原创生成纹理，实际3D地砖上覆盖表面材质；格位与地面拾取仍一致。建筑缩小后移，统一环境反射、明暗层次和光照方向。
- 商店采用更大的角色区和紧凑的品质/名称/职业/技能信息。未激活羁绊压缩显示，详细效果保留在提示中。

## 范围与限制

这是一名角色的美术制作样板，不是54名角色都已完成骨骼重制。裁决巨像的三个星级共享基础网格，当前通过体型和小型冠饰区分，尚未制作三套独立网格。其他角色和部分旧特效仍沿用此前素材；建筑与UI也仍有继续统一的空间。

默认使用Forward+，Windows便携包提供“兼容模式.cmd”强制OpenGL。实际录像不带声音，按采集时间编码，不能当作正式性能基准。

## 素材与提示词

全部新设定使用内置生图工具，未调用付费图像API。Tripo严格使用网页版，未使用API生成。

| 素材 | 文件 | 完整提示词 |
|---|---|---|
| 裁决巨像设定 | [PNG](../godot/wanxiang/assets/concepts/verdict-colossus-v2.png) | [Prompt](../godot/hero-art-v2-prompt.txt) |
| 学园石板 | [PNG](../godot/wanxiang/assets/academy-slab-v2.png) | [Prompt](../godot/paving-v2-prompt.txt) |
| 银杏盆栽设定 | [PNG](../godot/wanxiang/assets/concepts/academy-ginkgo-v1.png) | [Prompt](../godot/garden-v1-prompt.txt) |
| 骨骼角色 | [GLB](../godot/wanxiang/assets/models/verdict-colossus-v2.glb) | [来源记录](../godot/wanxiang/assets/models/PROVENANCE.txt) |
| 银杏景物 | [GLB](../godot/wanxiang/assets/models/academy-ginkgo.glb) | 同上 |

Tripo网页本次消耗165积分：角色55、智能重拓扑35、骨骼绑定20、银杏55。六个预设动作和导出未观察到额外扣费。

## 验证

`test_hero.gd`检查实际模型导入、65骨骼、六个真实动作、行走时骨骼变化、实际目标朝向、攻击、施法、暂停、眩晕中断、受击、升星和倒地清理。原生鼠标拖拽回归通过，包括上下场、满员交换和取消拖拽。物理棋盘拾取与特效生命周期测试通过；Forward+和OpenGL都完成GPU实机检查。

同时修复了公理之龙战前growth/heal选项到新技能grow/cleanse分支的映射；后端测试验证对应增益与净化。3D试演独立于联赛存档，沿用实际战斗属性和技能。

环境反射配置参考[Godot Environment文档](https://docs.godotengine.org/en/4.6/classes/class_environment.html)。
