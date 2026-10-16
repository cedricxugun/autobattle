extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(512,640);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X
 root.add_child(viewport)
 var env:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_CLEAR_COLOR
 var sky:=Sky.new();var atmosphere:=ProceduralSkyMaterial.new();atmosphere.sky_top_color=Color("95b4d1");atmosphere.sky_horizon_color=Color("e6dfc9");atmosphere.ground_bottom_color=Color("3d4c64");atmosphere.ground_horizon_color=Color("b8c8ce");sky.sky_material=atmosphere;settings.sky=sky
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;settings.ambient_light_energy=.6;settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY;settings.tonemap_mode=Environment.TONE_MAPPER_ACES;env.environment=settings;viewport.add_child(env)
 var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-40,-35,0);key.light_energy=1.3;viewport.add_child(key)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,145,0);fill.light_color=Color("b9d3ff");fill.light_energy=.45;viewport.add_child(fill)
 var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(2.0,1.7,3.5);camera.look_at(Vector3(0,.9,0));camera.fov=32;camera.current=true
 var hero:Node3D=load("res://scripts/hero_actor.gd").new();viewport.add_child(hero)
 var u:Dictionary={"id":51,"star":1,"x":0.0,"y":0.0,"team":0,"alive":true,"bench":true}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/portraits"))
 for star in [1,2,3]:
  u.star=star
  for i in 24:
   hero.drive(u,1.0,.016,false,false)
   await process_frame
  await RenderingServer.frame_post_draw
  var file:="res://assets/portraits/verdict-v2-star%d.png"%star
  viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(file));print("PORTRAIT ",file)
 quit()
