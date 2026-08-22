#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex3;

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

vec3 extractBloom(vec3 sceneColor, vec3 emissionColor) {
	float brightness = max(
		sceneColor.r,
		max(sceneColor.g, sceneColor.b)
	);
	float screenMask = smoothstep(
		BLOOM_THRESHOLD - BLOOM_KNEE,
		BLOOM_THRESHOLD + BLOOM_KNEE,
		brightness
	);
	vec3 screenBloom = sceneColor * screenMask * 0.35;
	float emissionBrightness = max(
		emissionColor.r,
		max(emissionColor.g, emissionColor.b)
	);
	float adaptiveEmissionGain = mix(
		1.50,
		2.20,
		smoothstep(0.15, 0.90, emissionBrightness)
	);
	vec3 emissiveBloom = emissionColor * adaptiveEmissionGain;
	return max(screenBloom, emissiveBloom);
}

vec3 sampleExtractedBloom(vec2 sampleUV) {
	vec3 sceneSample = texture(colortex0, sampleUV).rgb;
	vec3 emissionSample = texture(colortex3, sampleUV).rgb;
	return extractBloom(sceneSample, emissionSample);
}

void main() {
	vec2 sourceSize = vec2(textureSize(colortex0, 0));
	vec2 sourceTexel = 1.0 / sourceSize;
	vec2 halfTexel = sourceTexel * 0.5;

	vec3 extracted = vec3(0.0);
	extracted += sampleExtractedBloom(getSafeSourceUV(vec2(-0.5, -0.5) * sourceTexel, halfTexel));
	extracted += sampleExtractedBloom(getSafeSourceUV(vec2( 0.5, -0.5) * sourceTexel, halfTexel));
	extracted += sampleExtractedBloom(getSafeSourceUV(vec2(-0.5,  0.5) * sourceTexel, halfTexel));
	extracted += sampleExtractedBloom(getSafeSourceUV(vec2( 0.5,  0.5) * sourceTexel, halfTexel));
	extracted *= 0.25;

	bloomColor = vec4(extracted, 1.0);
}
