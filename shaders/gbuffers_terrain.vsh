#version 330 compatibility

in vec2 mc_Entity;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
flat out float blockId;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	blockId = mc_Entity.x;
}
