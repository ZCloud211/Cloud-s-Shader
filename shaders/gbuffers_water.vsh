#version 330 compatibility

in vec2 mc_Entity;

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 worldPosition;
flat out float blockId;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	vec3 viewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
	vec3 playerPosition = (gbufferModelViewInverse *
		vec4(viewPosition, 1.0)).xyz;
	worldPosition = playerPosition + cameraPosition;
	blockId = mc_Entity.x;
}
