#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

/* const int colortex1Format = RGBA16F; */
const vec4 colortex1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 bloomColor;

const float BLOOM_THRESHOLD = 0.88;
const float BLOOM_KNEE = 0.10;

vec2 getSafeSourceUV(vec2 offset, vec2 halfTexel) {
	return clamp(texcoord + offset, halfTexel, vec2(1.0) - halfTexel);
}

vec3 extractBloom(vec3 color) {
	float brightness = max(color.r, max(color.g, color.b));
	float mask = smoothstep(
		BLOOM_THRESHOLD - BLOOM_KNEE,
		BLOOM_THRESHOLD + BLOOM_KNEE,
		brightness
	);
	return color * mask;
}

void main() {
	vec2 sourceSize = vec2(textureSize(colortex0, 0));
	vec2 sourceTexel = 1.0 / sourceSize;
	vec2 halfTexel = sourceTexel * 0.5;

	vec3 extracted = vec3(0.0);
	extracted += extractBloom(texture(colortex0, getSafeSourceUV(vec2(-0.5, -0.5) * sourceTexel, halfTexel)).rgb);
	extracted += extractBloom(texture(colortex0, getSafeSourceUV(vec2( 0.5, -0.5) * sourceTexel, halfTexel)).rgb);
	extracted += extractBloom(texture(colortex0, getSafeSourceUV(vec2(-0.5,  0.5) * sourceTexel, halfTexel)).rgb);
	extracted += extractBloom(texture(colortex0, getSafeSourceUV(vec2( 0.5,  0.5) * sourceTexel, halfTexel)).rgb);
	extracted *= 0.25;

	bloomColor = vec4(extracted, 1.0);
}
