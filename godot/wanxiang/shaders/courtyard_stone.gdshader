shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stone_tint : source_color = vec4(0.62,0.73,0.77,1.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
	vec3 weight=pow(abs(world_normal),vec3(6.0));
	weight/=max(dot(weight,vec3(1.0)),0.001);
	vec3 paint=texture(stone_texture,world_position.yz/3.3).rgb*weight.x
		+texture(stone_texture,world_position.xz/3.3).rgb*weight.y
		+texture(stone_texture,world_position.xy/3.3).rgb*weight.z;
	ALBEDO=paint*stone_tint.rgb;
	ROUGHNESS=0.91;
	SPECULAR=0.12;
}
