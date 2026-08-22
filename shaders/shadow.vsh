#version 330 compatibility

#include "/lib/shadow_distort.glsl"
#include "/lib/waving_grass.glsl"

in vec2 mc_Entity;
in vec4 at_midBlock;

out vec2 texcoord;
out vec4 glcolor;

void main() {
	vec4 vertex = gl_Vertex;
	vertex.xyz += getGrassWindOffset(vertex.xyz, at_midBlock.xyz / 64.0, mc_Entity.x);
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vertex;
	gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
}
