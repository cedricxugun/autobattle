extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var document:=GLTFDocument.new()
 var state:=GLTFState.new()
 print("IMPORT ",document.append_from_file("res://assets/models/verdict-colossus-v2.glb",state))
 var model:=document.generate_scene(state)
 root.add_child(model)
 model.print_tree_pretty()
 for node in model.find_children("*","Skeleton3D",true,false):
  print("SKELETON ",node.get_path()," COUNT ",node.get_bone_count()," BONE0 ",node.get_bone_name(0))
  print("HEAD REST ",node.get_bone_global_rest(node.find_bone("mixamorig_Head")))
 for node in model.find_children("*","AnimationPlayer",true,false):
  print("PLAYER ",node.get_path()," ROOT ",node.root_node)
  for key in node.get_animation_list():
   var a:Animation=node.get_animation(key)
   print("ANIMATION ",key," LEN ",a.length," PATH ",a.track_get_path(0))
 quit()
