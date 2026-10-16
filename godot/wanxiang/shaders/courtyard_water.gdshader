shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float wave=sin(world_position.x*1.4+TIME*.55)*sin(world_position.z*2.3-TIME*.4);
	ALBEDO=vec3(.050,.130,.180)+vec3(wave*.006);
	ROUGHNESS=.34;
	METALLIC=.30;
}
