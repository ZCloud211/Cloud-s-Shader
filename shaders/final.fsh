#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform float sunAngle;

in vec2 texcoord;

layout(location = 0) out vec4 color;

const float NEAR_BLOOM_RESPONSE = 0.24;
const float WIDE_BLOOM_RESPONSE = 0.08;

const float TAU = 6.28318530718;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 sampleBilinear(sampler2D textureSampler, vec2 uv) {
	ivec2 textureSizePixels = textureSize(textureSampler, 0);
	vec2 texelPosition = uv * vec2(textureSizePixels) - 0.5;
	ivec2 baseTexel = ivec2(floor(texelPosition));
	vec2 fractionPart = fract(texelPosition);
	ivec2 maxTexel = textureSizePixels - ivec2(1);

	vec3 sample00 = texelFetch(textureSampler, clamp(baseTexel, ivec2(0), maxTexel), 0).rgb;
	vec3 sample10 = texelFetch(textureSampler, clamp(baseTexel + ivec2(1, 0), ivec2(0), maxTexel), 0).rgb;
	vec3 sample01 = texelFetch(textureSampler, clamp(baseTexel + ivec2(0, 1), ivec2(0), maxTexel), 0).rgb;
	vec3 sample11 = texelFetch(textureSampler, clamp(baseTexel + ivec2(1, 1), ivec2(0), maxTexel), 0).rgb;

	return mix(mix(sample00, sample10, fractionPart.x),
		mix(sample01, sample11, fractionPart.x), fractionPart.y);
}

vec3 applyEnvironmentGrade(vec3 sceneColor, float blockLight) {
	float solarHeight = sin(sunAngle * TAU);
	float dayFactor = smoothstep(-0.08, 0.12, solarHeight);
	float twilightFactor =
		1.0 - smoothstep(0.03, 0.28, abs(solarHeight));

	const vec3 DAY_TINT = vec3(1.03, 1.00, 0.96);
	const vec3 NIGHT_TINT = vec3(0.72, 0.82, 1.05);
	const vec3 TWILIGHT_TINT = vec3(1.10, 0.88, 0.70);
	const vec3 BLOCKLIGHT_TINT = vec3(1.10, 0.91, 0.72);

	vec3 environmentTint = mix(NIGHT_TINT, DAY_TINT, dayFactor);
	environmentTint = mix(
		environmentTint,
		TWILIGHT_TINT,
		twilightFactor * 0.55
	);

	float blockLightFactor = smoothstep(0.18, 0.88, blockLight);
	environmentTint = mix(
		environmentTint,
		BLOCKLIGHT_TINT,
		blockLightFactor * 0.55
	);

	float tintLuminance = dot(environmentTint, LUMA);
	environmentTint /= max(tintLuminance, 0.001);

	float exposure = mix(0.76, 1.00, dayFactor);
	exposure = mix(exposure, 0.84, twilightFactor * 0.45);
	exposure = mix(exposure, 0.95, blockLightFactor * 0.75);

	return clamp(sceneColor * environmentTint * exposure, 0.0, 1.0);
}

void main() {
	vec4 scene = texture(colortex0, texcoord);
	vec4 materialData = texture(colortex3, texcoord);
	float blockLight = materialData.a;
	scene.rgb = applyEnvironmentGrade(scene.rgb, blockLight);
	float emissionPeak = max(
		materialData.r,
		max(materialData.g, materialData.b)
	);
	float emitterCoreMask = smoothstep(0.05, 0.75, emissionPeak);
	float coreBloomSuppression = mix(1.0, 0.22, emitterCoreMask);
	vec3 nearBloom = sampleBilinear(colortex1, texcoord);
	vec3 wideBloom = sampleBilinear(colortex2, texcoord);
	vec3 nearBloomResponse =
		vec3(1.0) - exp(-nearBloom * NEAR_BLOOM_RESPONSE);
	vec3 wideBloomResponse =
		vec3(1.0) - exp(-wideBloom * WIDE_BLOOM_RESPONSE);
	vec3 bloomResponse = vec3(1.0) -
		(vec3(1.0) - nearBloomResponse) *
		(vec3(1.0) - wideBloomResponse);
	bloomResponse *= coreBloomSuppression;
	vec3 result = scene.rgb + (vec3(1.0) - scene.rgb) * bloomResponse;
	result = clamp(result, 0.0, 1.0);
	color = vec4(result, scene.a);
}
