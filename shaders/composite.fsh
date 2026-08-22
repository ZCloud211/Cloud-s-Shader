#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
	vec4 homogeneousPosition = projectionMatrix * vec4(position, 1.0);
	return homogeneousPosition.xyz / homogeneousPosition.w;
}

vec3 getShadowScreenPosition(vec2 screenUV, float depth) {
	vec3 ndcPosition = vec3(screenUV, depth) * 2.0 - 1.0;
	vec3 viewPosition = projectAndDivide(gbufferProjectionInverse, ndcPosition);
	vec3 playerPosition = (gbufferModelViewInverse
		* vec4(viewPosition, 1.0)).xyz;
	vec3 shadowViewPosition = (shadowModelView
		* vec4(playerPosition, 1.0)).xyz;
	vec4 shadowClipPosition = shadowProjection
		* vec4(shadowViewPosition, 1.0);

	// Side faces are the most susceptible to depth quantization acne. Keep one
	// clip-space-only bias before the divide; no normal, slope, or screen bias.
	shadowClipPosition.z -= 0.002;
	vec3 shadowNdcPosition = shadowClipPosition.xyz / shadowClipPosition.w;
	return shadowNdcPosition * 0.5 + 0.5;
}

float compareShadowDepth(vec2 shadowUV, float comparisonDepth) {
	if (shadowUV.x <= 0.0 || shadowUV.x >= 1.0 ||
		shadowUV.y <= 0.0 || shadowUV.y >= 1.0) {
		return 1.0;
	}

	float storedDepth = texture(shadowtex0, shadowUV).r;
	return step(comparisonDepth, storedDepth);
}

float sampleStableShadow(vec3 shadowScreenPosition) {
	if (shadowScreenPosition.x <= 0.0 || shadowScreenPosition.x >= 1.0 ||
		shadowScreenPosition.y <= 0.0 || shadowScreenPosition.y >= 1.0 ||
		shadowScreenPosition.z <= 0.0 || shadowScreenPosition.z >= 1.0) {
		return 1.0;
	}

	vec2 resolution = vec2(textureSize(shadowtex0, 0));
	vec2 texelPosition = shadowScreenPosition.xy * resolution - 0.5;
	vec2 baseTexel = floor(texelPosition);
	vec2 fractionPart = fract(texelPosition);

	vec2 uv00 = (baseTexel + vec2(0.5, 0.5)) / resolution;
	vec2 uv10 = (baseTexel + vec2(1.5, 0.5)) / resolution;
	vec2 uv01 = (baseTexel + vec2(0.5, 1.5)) / resolution;
	vec2 uv11 = (baseTexel + vec2(1.5, 1.5)) / resolution;

	float s00 = compareShadowDepth(uv00, shadowScreenPosition.z);
	float s10 = compareShadowDepth(uv10, shadowScreenPosition.z);
	float s01 = compareShadowDepth(uv01, shadowScreenPosition.z);
	float s11 = compareShadowDepth(uv11, shadowScreenPosition.z);

	float row0 = mix(s00, s10, fractionPart.x);
	float row1 = mix(s01, s11, fractionPart.x);
	return mix(row0, row1, fractionPart.y);
}

void main() {
	color = texture(colortex0, texcoord);

	float depth = texture(depthtex0, texcoord).r;
	if (depth >= 0.999999) {
		return;
	}

	vec3 shadowScreenPosition = getShadowScreenPosition(texcoord, depth);
	float shadow = sampleStableShadow(shadowScreenPosition);
	const float shadowAmbient = 0.42;
	vec4 materialData = texture(colortex3, texcoord);
	vec3 emissionColor = materialData.rgb;
	float blockLight = materialData.a;
	float sunShadowFactor = mix(shadowAmbient, 1.0, shadow);
	float blockLightProtection = smoothstep(0.10, 0.85, blockLight);
	float combinedShadowFactor = mix(
		sunShadowFactor,
		1.0,
		blockLightProtection
	);
	color.rgb *= combinedShadowFactor;
	color.rgb = max(color.rgb, emissionColor);
}
