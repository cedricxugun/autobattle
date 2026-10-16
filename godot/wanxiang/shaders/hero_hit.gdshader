shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform float flash=0.0;
void fragment(){ALBEDO=vec3(1.0,.78,.42);ALPHA=flash*.65;}
