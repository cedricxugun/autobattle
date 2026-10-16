shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stone_tint : source_color = vec4(0.32,0.40,0.48,1.0);
uniform sampler2D tile_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool battle_tile = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 weights=pow(abs(world_normal),vec3(6.0));weights/=max(dot(weights,vec3(1.0)),0.001);
 vec3 grain=texture(stone_texture,world_position.yz/4.0).rgb*weights.x+texture(stone_texture,world_position.xz/4.0).rgb*weights.y+texture(stone_texture,world_position.xy/4.0).rgb*weights.z;
 float tone=dot(grain,vec3(.299,.587,.114));
 float top=smoothstep(.4,.9,world_normal.y);
 vec3 paint=stone_tint.rgb*(.94+tone*.14);
 if(battle_tile){
  paint=mix(paint,texture(tile_texture,UV).rgb*1.4,.6);
  float edge=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
  paint*=mix(.77,1.0,smoothstep(.006,.035,edge)*top+(1.0-top));
 }else{
  vec2 slab=fract(world_position.xz*.7);
  float edge=min(min(slab.x,1.0-slab.x),min(slab.y,1.0-slab.y));
  paint*=mix(.88,1.0,smoothstep(.004,.014,edge)*top+(1.0-top));
 }
 ALBEDO=paint;
 ROUGHNESS=.72;
 SPECULAR=.28;
}
