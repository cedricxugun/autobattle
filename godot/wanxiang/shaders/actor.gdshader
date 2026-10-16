shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 school_color : source_color = vec4(0.4, 0.8, 0.9, 1.0);
void fragment() {
 vec4 base = COLOR;
 base.rgb = mix(base.rgb, vec3(1.0, 0.93, 0.78), flash * 0.72);
 base.rgb += school_color.rgb * charge * 0.28;
 if(dissolve>0.0){
   float grain=fract(sin(dot(floor(UV*110.0),vec2(12.9898,78.233)))*43758.5453);
   float edge=grain-dissolve;
   base.rgb=mix(base.rgb,school_color.rgb,1.0-smoothstep(0.0,0.08,edge));
   base.a*=smoothstep(0.0,0.04,edge);
 }
 COLOR = base;
}
