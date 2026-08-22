#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0,3,4 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 materialData;
layout(location = 2) out vec4 waterData;

void main() {
	vec4 handColor = texture(gtexture, texcoord) * glcolor;
	handColor.rgb *= texture(lightmap, lmcoord).rgb;
	if (handColor.a < alphaTestRef) {
		discard;
	}

	color = handColor;
	float handBlockLight = clamp(lmcoord.x, 0.0, 1.0);
	materialData = vec4(0.0, 0.0, 0.0, handBlockLight);
	waterData = vec4(0.0);
}
