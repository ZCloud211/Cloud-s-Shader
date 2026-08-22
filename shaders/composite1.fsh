#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

/* const int colortex1Format = RGBA16F; */
/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 bloomColor;

const float BLOOM_THRESHOLD = 0.88;
const float BLOOM_KNEE = 0.10;

void main() {
	vec3 scene = texture(colortex0, texcoord).rgb;
	float brightness = max(scene.r, max(scene.g, scene.b));
	float bloomMask = smoothstep(
		BLOOM_THRESHOLD - BLOOM_KNEE,
		BLOOM_THRESHOLD + BLOOM_KNEE,
		brightness
	);

	vec3 extracted = scene * bloomMask;
	bloomColor = vec4(extracted, 1.0);
}
