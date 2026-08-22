#version 330 compatibility

uniform sampler2D colortex1;

in vec2 texcoord;

/* const int colortex2Format = RGBA16F; */
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 bloomColor;

vec2 getSafeSourceUV(vec2 offset, vec2 halfTexel) {
	return clamp(texcoord + offset, halfTexel, vec2(1.0) - halfTexel);
}

void main() {
	vec2 sourceSize = vec2(textureSize(colortex1, 0));
	vec2 sourceTexel = 1.0 / sourceSize;
	vec2 halfTexel = sourceTexel * 0.5;

	vec3 bloom = vec3(0.0);
	bloom += texture(colortex1, getSafeSourceUV(vec2(-0.5, -0.5) * sourceTexel, halfTexel)).rgb;
	bloom += texture(colortex1, getSafeSourceUV(vec2( 0.5, -0.5) * sourceTexel, halfTexel)).rgb;
	bloom += texture(colortex1, getSafeSourceUV(vec2(-0.5,  0.5) * sourceTexel, halfTexel)).rgb;
	bloom += texture(colortex1, getSafeSourceUV(vec2( 0.5,  0.5) * sourceTexel, halfTexel)).rgb;
	bloomColor = vec4(bloom * 0.25, 1.0);
}
