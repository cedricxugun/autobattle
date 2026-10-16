extends SceneTree
var failed:=false
func _initialize() -> void:call_deferred("run")
func check(ok:bool,text:String) -> void:
 print(("PASS " if ok else "FAIL ")+text)
 failed=failed or not ok
func run() -> void:
 var actor:Node3D=load("res://scripts/hero_actor.gd").new()
 root.add_child(actor)
 await process_frame
 check(actor.ready_model,"real rigged GLB loaded")
 for key in ["idle","walk","punch","cast","hit","fall"]:check(actor.clips.has(key),"actual animation track "+key)
 var skeleton:Skeleton3D=actor.model.find_children("*","Skeleton3D",true,false)[0]
 check(skeleton.get_bone_count()==65,"65-bone skinned character")
 var unit:Dictionary={"id":51,"star":1,"x":2.0,"y":5.0,"aimX":2.0,"aimY":2.0,"team":0,"alive":true,"moving":false,"casting":false,"buffs":[]}
 actor.drive(unit,1,.2,false,false)
 check(absf(absf(actor.rotation.y)-PI)<.01,"model front faces actual target")
 unit.moving=true;actor.drive(unit,1.1,.1,false,false)
 check(actor.player.current_animation==actor.clips.walk,"movement uses walk clip")
 var arm:=skeleton.find_bone("mixamorig_LeftArm")
 actor.player.advance(.15)
 var pose:=skeleton.get_bone_pose_rotation(arm)
 actor.player.advance(.3)
 check(not pose.is_equal_approx(skeleton.get_bone_pose_rotation(arm)),"walk deforms skeleton rather than sliding a still image")
 unit.moving=false;unit.attackWindupAt=1.2;actor.drive(unit,1.25,.05,false,false)
 check(actor.player.current_animation==actor.clips.punch,"basic attack plays punch clip")
 unit.casting=true;unit.skillWindupAt=2.0;unit.castEnd=3.1;actor.drive(unit,2.5,.05,false,false)
 check(actor.player.current_animation==actor.clips.cast,"skill uses cast clip")
 actor.drive(unit,2.5,.05,true,false)
 check(is_zero_approx(actor.player.speed_scale),"pause freezes skeletal animation")
 unit.casting=false;unit.buffs=["stun"];actor.drive(unit,2.6,.05,false,false)
 check(actor.player.current_animation==actor.clips.hit and is_zero_approx(actor.player.speed_scale),"stun interrupts cast pose")
 unit.buffs=[];unit.hitAt=3.0;actor.drive(unit,3.02,.02,false,false)
 check(actor.player.current_animation==actor.clips.hit,"damage uses reaction clip")
 unit.star=3;actor.drive(unit,3.4,.1,false,false)
 check(actor.halo.visible and actor.pose_root.scale.x>1.1,"three-star silhouette changes")
 unit.alive=false;actor.drive(unit,4,.1,false,false)
 check(actor.player.current_animation==actor.clips.fall,"death uses fall clip")
 actor.drive(unit,5,.1,false,false)
 check(not actor.visible,"dead body finishes and disappears")
 actor.queue_free();await process_frame
 quit(1 if failed else 0)
