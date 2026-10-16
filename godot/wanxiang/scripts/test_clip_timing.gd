extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var doc:=GLTFDocument.new();var state:=GLTFState.new();doc.append_from_file("res://assets/models/verdict-colossus-v2.glb",state)
 var model:=doc.generate_scene(state);root.add_child(model)
 var player:AnimationPlayer=model.get_node("AnimationPlayer")
 var skel:Skeleton3D=model.get_node("Armature/Skeleton3D")
 for clip in ["cast_a_spell","box_01"]:
  player.play(clip)
  for step in 12:
   var t:float=player.get_animation(clip).length*step/11
   player.seek(t,true);player.advance(0)
   print(clip," ",snappedf(t,.01)," R ",skel.get_bone_global_pose(skel.find_bone("mixamorig_RightHand")).origin," L ",skel.get_bone_global_pose(skel.find_bone("mixamorig_LeftHand")).origin)
 quit()
