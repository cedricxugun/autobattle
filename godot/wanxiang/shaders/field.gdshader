shader_type canvas_item;
render_mode unshaded;
uniform float elapsed = 0.0;
uniform float opacity = 1.0;
uniform int school = 0;
uniform vec4 tint : source_color = vec4(0.3, 0.7, 0.9, 1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
void fragment(){
 vec2 p=(UV-0.5)*2.0;float r=length(p);float a=atan(p.y,p.x);
 float edge=1.0-smoothstep(0.94,1.0,r);
 float line=exp(-abs(r-0.94)*90.0);
 float flow=0.0;
 if(school==1){float spiral=sin(r*24.0+a*4.0+elapsed*5.0);flow=pow(max(0.0,spiral),8.0)*(1.0-r)*0.65;}
 else if(school==2){float n=noise(p*5.0+vec2(elapsed*0.3,-elapsed*0.45));flow=smoothstep(0.45,0.8,n)*0.38+0.05;}
 else if(school==4){float n=noise(p*4.0+elapsed*0.15);flow=smoothstep(0.35,0.8,n)*0.14;}
 else {flow=pow(max(0.0,sin(r*19.0-elapsed*2.0)),24.0)*0.13;}
 COLOR=vec4(tint.rgb,(flow+line*0.6)*edge*opacity);
}
