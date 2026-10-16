shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D field_texture : filter_linear;
void fragment(){
 vec4 sample_color=texture(field_texture,UV);
 ALBEDO=sample_color.rgb/max(sample_color.a,0.015);
 ALPHA=clamp(sample_color.a*1.2,0.0,0.9);
}
