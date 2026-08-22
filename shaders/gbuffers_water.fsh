#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D noisetex;

uniform float alphaTestRef = 0.1;
uniform float frameTimeCounter;
uniform mat4 gbufferModelView;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 worldPosition;
flat in vec3 worldGeometryNormal;
flat in float blockId;

/* const int colortex4Format = RGBA8; */
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 waterData;

const int noiseTextureResolution = 256;
const float WATER_NORMAL_STRENGTH = 1.05;
const float WATER_NORMAL_MAX_SLOPE = 0.18;

ivec2 wrapNoiseCell(ivec2 cell) {
	ivec2 wrappedCell = cell % noiseTextureResolution;
	if (wrappedCell.x < 0) {
		wrappedCell.x += noiseTextureResolution;
	}
	if (wrappedCell.y < 0) {
		wrappedCell.y += noiseTextureResolution;
	}
	return wrappedCell;
}

float sampleNoiseCell(ivec2 cell, int channel) {
	vec3 noiseValue = texelFetch(noisetex, wrapNoiseCell(cell), 0).rgb;
	if (channel == 0) {
		return noiseValue.r;
	}
	if (channel == 1) {
		return noiseValue.g;
	}
	return noiseValue.b;
}

float smoothValueNoise(vec2 position, int channel) {
	ivec2 baseCell = ivec2(floor(position));
	vec2 fractionPart = fract(position);
	vec2 smoothFraction = fractionPart * fractionPart *
		(3.0 - 2.0 * fractionPart);

	float value00 = sampleNoiseCell(baseCell, channel);
	float value10 = sampleNoiseCell(baseCell + ivec2(1, 0), channel);
	float value01 = sampleNoiseCell(baseCell + ivec2(0, 1), channel);
	float value11 = sampleNoiseCell(baseCell + ivec2(1, 1), channel);
	float row0 = mix(value00, value10, smoothFraction.x);
	float row1 = mix(value01, value11, smoothFraction.x);
	return mix(row0, row1, smoothFraction.y);
}

float getOctaveFilter(float pixelFootprint, float octaveScale) {
	return 1.0 - smoothstep(
		0.18,
		0.62,
		pixelFootprint * octaveScale
	);
}

float evaluateWaterHeight(
	vec2 worldXZ,
	float time,
	float pixelFootprint
) {
	vec2 layer1Position = mat2(0.96, -0.28, 0.18, 0.99) * worldXZ * 0.055 +
		normalize(vec2(0.83, 0.56)) * time * 0.018 + vec2(17.0, -9.0);
	vec2 layer2Position = mat2(0.84, 0.39, -0.31, 0.91) * worldXZ * 0.113 +
		normalize(vec2(-0.38, 0.93)) * time * 0.027 + vec2(-23.0, 14.0);
	vec2 layer3Position = mat2(1.03, -0.21, 0.16, 0.95) * worldXZ * 0.227 +
		normalize(vec2(0.64, -0.77)) * time * 0.038 + vec2(41.0, 5.0);
	vec2 layer4Position = mat2(0.73, 0.62, -0.48, 0.86) * worldXZ * 0.463 +
		normalize(vec2(-0.91, -0.42)) * time * 0.055 + vec2(-11.0, -37.0);
	vec2 layer5Position = mat2(1.08, 0.17, -0.26, 0.89) * worldXZ * 0.917 +
		normalize(vec2(0.27, -0.96)) * time * 0.080 + vec2(29.0, 31.0);
	vec2 layer6Position = mat2(0.68, -0.74, 0.57, 0.81) * worldXZ * 1.590 +
		normalize(vec2(-0.69, 0.72)) * time * 0.120 + vec2(-47.0, 19.0);

	float layer1 = smoothValueNoise(layer1Position, 0) * 2.0 - 1.0;
	float layer2 = smoothValueNoise(layer2Position, 1) * 2.0 - 1.0;
	float layer3 = smoothValueNoise(layer3Position, 2) * 2.0 - 1.0;
	float layer4 = smoothValueNoise(layer4Position, 1) * 2.0 - 1.0;
	float ridge5 = 1.0 - abs(smoothValueNoise(layer5Position, 0) * 2.0 - 1.0);
	float ridge6 = 1.0 - abs(smoothValueNoise(layer6Position, 2) * 2.0 - 1.0);

	float height = layer1 * 0.100 * getOctaveFilter(pixelFootprint, 0.055);
	height += layer2 * 0.065 * getOctaveFilter(pixelFootprint, 0.113);
	height += layer3 * 0.043 * getOctaveFilter(pixelFootprint, 0.227);
	height += layer4 * 0.022 * getOctaveFilter(pixelFootprint, 0.463);
	height += (ridge5 * 2.0 - 1.0) * 0.006 *
		getOctaveFilter(pixelFootprint, 0.917);
	height += (ridge6 * 2.0 - 1.0) * 0.002 *
		getOctaveFilter(pixelFootprint, 1.590);
	return height;
}

void main() {
	vec4 baseWater = texture(gtexture, texcoord) * glcolor;
	if (baseWater.a < alphaTestRef) {
		discard;
	}
	baseWater.rgb *= texture(lightmap, lmcoord).rgb;
	color = baseWater;

	float pixelFootprint = max(
		length(dFdx(worldPosition.xz)),
		length(dFdy(worldPosition.xz))
	);
	bool isWater = abs(blockId - 10091.0) < 0.5;
	if (!isWater) {
		waterData = vec4(0.0);
		return;
	}

	const float sampleDistance = 0.065;
	float heightCenter = evaluateWaterHeight(
		worldPosition.xz,
		frameTimeCounter,
		pixelFootprint
	);
	float heightX = evaluateWaterHeight(
		worldPosition.xz + vec2(sampleDistance, 0.0),
		frameTimeCounter,
		pixelFootprint
	);
	float heightZ = evaluateWaterHeight(
		worldPosition.xz + vec2(0.0, sampleDistance),
		frameTimeCounter,
		pixelFootprint
	);
	vec2 heightSlope = vec2(
		(heightX - heightCenter) / sampleDistance,
		(heightZ - heightCenter) / sampleDistance
	) * WATER_NORMAL_STRENGTH;
	float slopeLength = length(heightSlope);
	if (slopeLength > WATER_NORMAL_MAX_SLOPE) {
		heightSlope *= WATER_NORMAL_MAX_SLOPE / slopeLength;
	}

	vec3 waveWorldNormal = normalize(
		vec3(-heightSlope.x, 1.0, -heightSlope.y)
	);
	float topSurfaceMask = smoothstep(0.65, 0.92, worldGeometryNormal.y);
	vec3 finalWorldNormal = normalize(
		mix(worldGeometryNormal, waveWorldNormal, topSurfaceMask)
	);
	vec3 viewNormal = normalize(mat3(gbufferModelView) * finalWorldNormal);
	vec3 encodedNormal = viewNormal * 0.5 + 0.5;
	waterData = vec4(encodedNormal, 1.0);
}
