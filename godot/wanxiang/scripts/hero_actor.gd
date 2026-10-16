extends Node3D
# A real skinned mesh; all copies share immutable mesh/animation resources.
static var cached:PackedScene
var model:Node3D
var player:AnimationPlayer
var meshes:Array[MeshInstance3D]=[]
var overlay:=ShaderMaterial.new()
var pose_root:=Node3D.new()
var current_action:=""
var attack_stamp:=-99.0
var cast_stamp:=-99.0
var hit_stamp:=-99.0
var dead_since:=-1.0
var last_star:=0
var halo:Node3D
var clips:Dictionary={}
var skeleton:Skeleton3D
var head_index:=-1
var ready_model:=false

func _ready() -> void:
 if cached==null:
  var doc:=GLTFDocument.new()
  var state:=GLTFState.new()
  if doc.append_from_file("res://assets/models/verdict-colossus-v2.glb",state)!=OK:return
  var source:=doc.generate_scene(state)
  _own(source,source)
  cached=PackedScene.new()
  cached.pack(source)
  source.free()
 add_child(pose_root)
 model=cached.instantiate()
 pose_root.add_child(model)
 var helper:Node3D=load("res://scripts/scenery_model.gd").new()
 var bounds:AABB=helper._bounds(model,Transform3D.IDENTITY)
 helper.free()
 var factor:=1.65/maxf(bounds.size.y,.01)
 model.scale=Vector3.ONE*factor
 model.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor
 overlay.shader=load("res://shaders/hero_hit.gdshader")
 for node in model.find_children("*","MeshInstance3D",true,false):
  var mesh:MeshInstance3D=node
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
  mesh.material_overlay=overlay
  meshes.append(mesh)
 for node in model.find_children("*","AnimationPlayer",true,false):player=node;break
 if player==null:return
 for key in player.get_animation_list():
  var anim:Animation=player.get_animation(key)
  var lower:=String(key).to_lower()
  for category in ["idle","walk","run","cast","slash","punch","hit","defeat","fall"]:
   if lower.contains(category):clips[category]=key
  if lower.contains("idle") or lower.contains("walk") or lower.contains("run"):anim.loop_mode=Animation.LOOP_LINEAR
  if lower.begins_with("box_"):
   clips["punch"]=key
 halo=Node3D.new()
 for node in model.find_children("*","Skeleton3D",true,false):skeleton=node;break
 head_index=skeleton.find_bone("mixamorig_Head")
 pose_root.add_child(halo)
 var gold:=StandardMaterial3D.new();gold.albedo_color=Color("aa803f");gold.metallic=.75;gold.roughness=.36
 var band:=MeshInstance3D.new();var circlet:=TorusMesh.new();circlet.inner_radius=.15;circlet.outer_radius=.175;circlet.rings=48;circlet.ring_segments=8
 band.mesh=circlet;band.material_override=gold;halo.add_child(band)
 for i in 7:
  var jewel:=MeshInstance3D.new()
  var point:=SphereMesh.new();point.radius=.012;point.height=.032+(.012 if i==3 else 0);point.radial_segments=12;point.rings=6
  jewel.mesh=point;jewel.material_override=gold
  var angle:float=(i-3)*.36
  jewel.position=Vector3(sin(angle)*.16,.012,cos(angle)*.16)
  jewel.scale.z=.55
  jewel.rotation.y=angle
  halo.add_child(jewel)
 halo.visible=false
 ready_model=true
 _play("idle",1.0)

func _own(node:Node,root:Node) -> void:
 if node!=root:node.owner=root
 for child in node.get_children():_own(child,root)

func _play(action:String,speed:float=1.0,force:bool=false) -> void:
 var key:String=clips.get(action,clips.get("idle",""))
 if key.is_empty():return
 if current_action!=action or force:
  player.play(key,.12,speed)
  current_action=action

func drive(u:Dictionary,clock:float,delta:float,paused:bool,dragged:bool,rate:float=1.0) -> void:
 if not ready_model:return
 var alive:bool=u.get("alive",true)
 var star:int=int(u.get("star",1))
 if star!=last_star:
  last_star=star;pose_root.scale=Vector3.ONE*(1.0+(star-1)*.065)
  halo.visible=star>=2;halo.scale=Vector3.ONE*(1.0 if star==2 else 1.14)
 if head_index>=0:halo.position=pose_root.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(head_index).origin)+Vector3(0,.11,0)
 player.speed_scale=0.0 if paused else rate
 visible=not dragged
 if paused:return
 if not alive:
  if dead_since<0:
   dead_since=clock
   var fall_key:String=clips.get("fall","")
   _play("fall",player.get_animation(fall_key).length/.9 if not fall_key.is_empty() else 1.5,true)
  var phase:=clampf((clock-dead_since)/.9,0,1)
  pose_root.rotation.z=phase*.45
  for m in meshes:m.transparency=phase
  visible=visible and phase<1
  return
 dead_since=-1;pose_root.rotation.z=0
 for m in meshes:m.transparency=0
 var target:=Vector2(float(u.get("aimX",u.x))-float(u.x),float(u.get("aimY",u.y))-float(u.y))
 var desired:float=atan2(target.x,target.y) if target.length()>.03 else (PI if int(u.team)==0 else 0.0)
 if u.get("bench",false):desired=0.0
 rotation.y=lerp_angle(rotation.y,desired,minf(1,delta*12))
 var attack:float=float(u.get("attackWindupAt",-99))
 var cast:float=float(u.get("skillWindupAt",-99))
 var hit:float=float(u.get("hitAt",-99))
 overlay.set_shader_parameter("flash",maxf(0,1-(clock-hit)/.14))
 if "stun" in u.get("buffs",[]):
  _play("hit",1.0)
  if clips.has("hit"):player.seek(player.get_animation(clips.hit).length*.25,true)
  player.speed_scale=0
 elif u.get("casting",false):
  _play("cast",1.0,cast!=cast_stamp);cast_stamp=cast
  if clips.has("cast"):
   var progress:=clampf((clock-cast)/maxf(.8,float(u.get("castEnd",clock))-cast),0,.98)
   player.seek(1.75+progress*1.55,true)
   player.speed_scale=0
 elif attack!=attack_stamp and clock-attack<.5:
  attack_stamp=attack
  _play("punch",1.0,true)
  _sample_punch(clock-attack)
 elif clock-attack<.55 and current_action=="punch":_sample_punch(clock-attack)
 elif hit!=hit_stamp and clock-hit<.14 and not u.get("moving",false):
  hit_stamp=hit
  var hurt_key:String=clips.get("hit","")
  _play("hit",player.get_animation(hurt_key).length/.25 if not hurt_key.is_empty() else 2.0,true)
 elif clock-hit<.25 and current_action=="hit":pass
 elif u.get("moving",false) and not "root" in u.get("buffs",[]):_play("walk",1.4)
 else:_play("idle",1.0)

func _sample_punch(age:float) -> void:
 if not clips.has("punch"):return
 # The fist reaches the opponent when the simulation's .18s attack commits.
 var moment:float=lerpf(.30,.60,clampf(age/.18,0,1)) if age<=.18 else lerpf(.60,1.05,clampf((age-.18)/.37,0,1))
 player.seek(moment,true)
 player.speed_scale=0
