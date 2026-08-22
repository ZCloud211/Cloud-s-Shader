// Natural grass wind: two broad wind waves plus a stable per-plant variation.
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

const float shortGrassId = 101.0;
const float tallGrassLowerId = 102.0;
const float tallGrassUpperId = 103.0;
const float deadBushId = 104.0;
const float grassWindAmplitude = 0.055;

float grassHash(vec2 position) {
	position = fract(position * vec2(0.1031, 0.11369));
	position += dot(position, position.yx + 19.19);
	return fract((position.x + position.y) * position.x);
}

bool isWavingGrass(float blockId) {
	return blockId == shortGrassId || blockId == tallGrassLowerId ||
		blockId == tallGrassUpperId || blockId == deadBushId;
}

vec3 getGrassWindOffset(vec3 playerVertexPosition, vec3 centerOffset, float blockId) {
	if (!isWavingGrass(blockId)) {
		return vec3(0.0);
	}

	// at_midBlock points from this vertex toward the block center.
	float localHeight = clamp(0.5 - centerOffset.y, 0.0, 1.0);
	if (blockId == tallGrassLowerId) {
		localHeight *= 0.5;
	} else if (blockId == tallGrassUpperId) {
		localHeight = 0.5 + localHeight * 0.5;
	}

	vec3 worldCenter = playerVertexPosition + centerOffset + cameraPosition;
	vec2 plantCell = floor(worldCenter.xz);
	float randomPhase = grassHash(plantCell) * 6.2831853;
	float time = frameTimeCounter;

	float broadPhase = dot(plantCell, vec2(0.19, 0.13)) + time * 1.10;
	float crossPhase = dot(plantCell, vec2(-0.08, 0.23)) - time * 0.72;
	vec2 broadWind = vec2(cos(broadPhase), sin(broadPhase * 0.91));
	vec2 crossWind = vec2(sin(crossPhase * 1.07), cos(crossPhase));
	vec2 localWind = vec2(cos(randomPhase), sin(randomPhase))
		* sin(time * 1.85 + randomPhase);

	vec2 windDirection = broadWind * 0.62 + crossWind * 0.28 + localWind * 0.20;
	float gust = 0.72 + 0.28 * sin(broadPhase + crossPhase * 0.35);
	float heightResponse = localHeight * localHeight;
	float plantScale = mix(0.82, 1.12, grassHash(plantCell + 17.0));
	if (blockId == deadBushId) {
		plantScale *= 0.55;
	}

	return vec3(windDirection * gust * heightResponse * grassWindAmplitude * plantScale, 0.0);
}
