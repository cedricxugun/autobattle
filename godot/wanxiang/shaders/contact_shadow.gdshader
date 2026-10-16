shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float opacity=0.5;
void fragment() {
	float d=length((UV-vec2(0.5))*2.0);
	ALBEDO=vec3(0.015,0.025,0.035);
	ALPHA=(1.0-smoothstep(0.15,1.0,d))*opacity;
}
