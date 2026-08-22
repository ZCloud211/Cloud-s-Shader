#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef = 0.1;

in vec2 texcoord;
in vec4 glcolor;

const int shadowMapResolution = 4096;
const float shadowDistance = 128.0;
const float shadowDistanceRenderMul = 1.0;
const bool shadowtex0Nearest = true;

layout(location = 0) out vec4 color;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) {
		discard;
	}
}
