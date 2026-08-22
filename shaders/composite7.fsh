#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;

uniform float sunAngle;
uniform float rainStrength;

uniform int isEyeInWater;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const bool DEBUG_OPAQUE_SCENE = false;
const bool DEBUG_WATER_NORMAL = false;
const bool DEBUG_WATER_THICKNESS = false;
const bool DEBUG_WATER_REFRACTION = false;
const bool DEBUG_WATER_FRESNEL = false;
const bool DEBUG_WATER_SSR = false;
const bool DEBUG_WATER_REFRACTION_NORMAL = false;
const bool DEBUG_WATER_REFLECTION_NORMAL = false;
const bool DEBUG_WATER_ROUGHNESS = false;
const bool DEBUG_WATER_SPECULAR = false;
const bool DEBUG_WATER_TRANSMISSION_LOD = false;
const bool DEBUG_WATER_FRONTMOST_VALIDITY = false;
const bool DEBUG_REFRACTION_CONTINUITY = false;
const bool DEBUG_HAND_REJECTION = false;
const bool DEBUG_SAFE_REFRACTION_LOD = false;
const bool DEBUG_WATER_REFRACTION_LEAK_DIAGNOSTIC = false;
const bool DEBUG_SSR_BINARY_HIT = false;
const bool DEBUG_SSR_HIT_DISTANCE = false;
const bool DEBUG_SSR_RAW_COLOR = false;
const bool DEBUG_SSR_CONFIDENCE_COMPONENTS = false;
const bool DEBUG_REFLECTION_WEIGHT = false;
const bool DEBUG_SCREEN_SKY_REFLECTION = false;
const bool DEBUG_DIRECT_SPECULAR_FINAL = false;

const bool colortex5MipmapEnabled = true;

const int SSR_MAX_STEPS = 32;
const int SSR_REFINEMENT_STEPS = 4;
const float SSR_MAX_DISTANCE = 32.0;

vec3 reconstructViewPosition(vec2 screenUV, float depth) {
	vec3 ndcPosition = vec3(screenUV, depth) * 2.0 - 1.0;
	vec4 viewPosition = gbufferProjectionInverse * vec4(ndcPosition, 1.0);
	return viewPosition.xyz / viewPosition.w;
}

float getNearestWaterMask(vec2 screenUV) {
	ivec2 waterSize = textureSize(colortex4, 0);
	ivec2 waterPixel = ivec2(floor(screenUV * vec2(waterSize)));
	waterPixel = clamp(waterPixel, ivec2(0), waterSize - ivec2(1));
	return texelFetch(colortex4, waterPixel, 0).a;
}

bool hasHandAtUV(vec2 screenUV) {
	float handDepth = texture(depthtex1, screenUV).r;
	if (handDepth >= 0.999999) {
		return false;
	}

	float worldDepth = texture(depthtex2, screenUV).r;
	if (worldDepth >= 0.999999) {
		return true;
	}

	vec3 handViewPosition = reconstructViewPosition(screenUV, handDepth);
	vec3 worldViewPosition = reconstructViewPosition(screenUV, worldDepth);
	float depthEpsilon = max(
		0.015,
		max(abs(handViewPosition.z), abs(worldViewPosition.z)) * 0.001
	);
	return abs(handViewPosition.z - worldViewPosition.z) > depthEpsilon;
}

bool isFrontmostWaterAtUV(
	vec2 screenUV,
	out vec3 frontViewPosition,
	out vec3 opaqueViewPosition,
	out float opaqueDepth
) {
	float frontDepth = texture(depthtex0, screenUV).r;
	frontViewPosition = vec3(0.0);
	opaqueViewPosition = vec3(0.0);
	opaqueDepth = texture(depthtex1, screenUV).r;
	if (frontDepth >= 0.999999) {
		return false;
	}

	frontViewPosition = reconstructViewPosition(screenUV, frontDepth);
	if (opaqueDepth >= 0.999999) {
		return true;
	}

	opaqueViewPosition = reconstructViewPosition(screenUV, opaqueDepth);
	float depthEpsilon = max(0.015, abs(frontViewPosition.z) * 0.001);
	return opaqueViewPosition.z < frontViewPosition.z - depthEpsilon;
}

float getWaterLayerSampleContinuity(
	vec2 screenUV,
	float centerOpaqueDistance
) {
	if (screenUV.x <= 0.0 || screenUV.x >= 1.0 ||
		screenUV.y <= 0.0 || screenUV.y >= 1.0) {
		return 0.0;
	}
	if (getNearestWaterMask(screenUV) <= 0.5 || hasHandAtUV(screenUV)) {
		return 0.0;
	}

	vec3 sampleFrontPosition;
	vec3 sampleOpaquePosition;
	float sampleOpaqueDepth;
	if (!isFrontmostWaterAtUV(
		screenUV,
		sampleFrontPosition,
		sampleOpaquePosition,
		sampleOpaqueDepth
	)) {
		return 0.0;
	}

	float sampleOpaqueDistance = sampleOpaqueDepth >= 0.999999 ?
		24.0 : length(sampleOpaquePosition - sampleFrontPosition);
	float allowedDifference = max(0.20, centerOpaqueDistance * 0.025);
	float depthDifference = abs(sampleOpaqueDistance - centerOpaqueDistance);
	return 1.0 - smoothstep(
		allowedDifference * 0.55,
		allowedDifference,
		depthDifference
	);
}

float getRefractionContinuity(
	vec2 screenUV,
	float requestedLod,
	float centerOpaqueDistance
) {
	vec2 texelSize = 1.0 / vec2(textureSize(colortex5, 0));
	vec2 sampleRadius = texelSize * (exp2(requestedLod) + 0.5);
	vec2 offsets[8];
	offsets[0] = vec2(-sampleRadius.x, 0.0);
	offsets[1] = vec2( sampleRadius.x, 0.0);
	offsets[2] = vec2(0.0, -sampleRadius.y);
	offsets[3] = vec2(0.0,  sampleRadius.y);
	offsets[4] = vec2(-sampleRadius.x, -sampleRadius.y);
	offsets[5] = vec2( sampleRadius.x, -sampleRadius.y);
	offsets[6] = vec2(-sampleRadius.x,  sampleRadius.y);
	offsets[7] = vec2( sampleRadius.x,  sampleRadius.y);

	float continuity = getWaterLayerSampleContinuity(
		screenUV,
		centerOpaqueDistance
	);
	for (int sampleIndex = 0; sampleIndex < 8; ++sampleIndex) {
		continuity = min(
			continuity,
			getWaterLayerSampleContinuity(
				screenUV + offsets[sampleIndex],
				centerOpaqueDistance
			)
		);
	}
	return continuity;
}

float getOpaqueDepthContinuitySample(
	vec2 screenUV,
	float centerOpaqueViewDepth
) {
	if (screenUV.x <= 0.0 || screenUV.x >= 1.0 ||
		screenUV.y <= 0.0 || screenUV.y >= 1.0) {
		return 0.0;
	}
	float sampleDepth = texture(depthtex1, screenUV).r;
	if (sampleDepth >= 0.999999 || hasHandAtUV(screenUV)) {
		return 0.0;
	}

	float sampleViewDepth = reconstructViewPosition(screenUV, sampleDepth).z;
	float allowedDifference = max(0.20, abs(centerOpaqueViewDepth) * 0.025);
	float depthDifference = abs(sampleViewDepth - centerOpaqueViewDepth);
	return 1.0 - smoothstep(
		allowedDifference * 0.55,
		allowedDifference,
		depthDifference
	);
}

float getSsrDepthContinuity(vec2 screenUV, float requestedLod) {
	float centerDepth = texture(depthtex1, screenUV).r;
	if (centerDepth >= 0.999999) {
		return 0.0;
	}
	float centerViewDepth = reconstructViewPosition(screenUV, centerDepth).z;
	vec2 texelSize = 1.0 / vec2(textureSize(colortex5, 0));
	vec2 sampleRadius = texelSize * (exp2(requestedLod) + 0.5);
	vec2 offsets[8];
	offsets[0] = vec2(-sampleRadius.x, 0.0);
	offsets[1] = vec2( sampleRadius.x, 0.0);
	offsets[2] = vec2(0.0, -sampleRadius.y);
	offsets[3] = vec2(0.0,  sampleRadius.y);
	offsets[4] = vec2(-sampleRadius.x, -sampleRadius.y);
	offsets[5] = vec2( sampleRadius.x, -sampleRadius.y);
	offsets[6] = vec2(-sampleRadius.x,  sampleRadius.y);
	offsets[7] = vec2( sampleRadius.x,  sampleRadius.y);

	float continuity = getOpaqueDepthContinuitySample(
		screenUV,
		centerViewDepth
	);
	for (int sampleIndex = 0; sampleIndex < 8; ++sampleIndex) {
		continuity = min(
			continuity,
			getOpaqueDepthContinuitySample(
				screenUV + offsets[sampleIndex],
				centerViewDepth
			)
		);
	}
	return continuity;
}

bool projectToScreen(vec3 viewPosition, out vec2 screenUV) {
	vec4 clipPosition = gbufferProjection * vec4(viewPosition, 1.0);
	if (clipPosition.w <= 0.0) {
		return false;
	}
	vec2 ndcPosition = clipPosition.xy / clipPosition.w;
	screenUV = ndcPosition * 0.5 + 0.5;
	return screenUV.x > 0.0 && screenUV.x < 1.0 &&
		screenUV.y > 0.0 && screenUV.y < 1.0;
}

bool projectViewDirectionToScreen(vec3 viewDirection, out vec2 screenUV) {
	if (viewDirection.z >= -0.0001) {
		return false;
	}

	vec4 clipDirection = gbufferProjection * vec4(viewDirection, 0.0);
	if (clipDirection.w <= 0.0001) {
		return false;
	}
	vec2 ndcDirection = clipDirection.xy / clipDirection.w;
	screenUV = ndcDirection * 0.5 + 0.5;
	return screenUV.x > 0.0 && screenUV.x < 1.0 &&
		screenUV.y > 0.0 && screenUV.y < 1.0;
}

float getScreenEdgeFade(vec2 screenUV) {
	float edgeDistance = min(
		min(screenUV.x, 1.0 - screenUV.x),
		min(screenUV.y, 1.0 - screenUV.y)
	);
	return smoothstep(0.015, 0.08, edgeDistance);
}

vec3 calculateWaterDirectSpecular(
	vec3 normal,
	vec3 viewDirection,
	vec3 lightDirection,
	float roughness
) {
	const float WATER_F0 = 0.02037;
	const float PI = 3.14159265359;
	const float EPSILON = 0.0001;
	float NoV = max(dot(normal, viewDirection), EPSILON);
	float NoL = max(dot(normal, lightDirection), 0.0);
	if (NoL <= 0.0) {
		return vec3(0.0);
	}

	vec3 halfVector = viewDirection + lightDirection;
	float halfLength = length(halfVector);
	if (halfLength <= EPSILON) {
		return vec3(0.0);
	}
	vec3 halfDirection = halfVector / halfLength;
	float NoH = max(dot(normal, halfDirection), 0.0);
	float VoH = max(dot(viewDirection, halfDirection), 0.0);
	float alpha = roughness * roughness;
	float alphaSquared = alpha * alpha;
	float distributionDenominator = NoH * NoH *
		(alphaSquared - 1.0) + 1.0;
	float distribution = alphaSquared / max(
		PI * distributionDenominator * distributionDenominator,
		EPSILON
	);

	float geometryK = (roughness + 1.0) * (roughness + 1.0) * 0.125;
	float geometryView = NoV / max(
		NoV * (1.0 - geometryK) + geometryK,
		EPSILON
	);
	float geometryLight = NoL / max(
		NoL * (1.0 - geometryK) + geometryK,
		EPSILON
	);
	float geometry = geometryView * geometryLight;
	float fresnel = WATER_F0 +
		(1.0 - WATER_F0) * pow(1.0 - VoH, 5.0);
	float specular = distribution * geometry * fresnel * NoL /
		max(4.0 * NoV * NoL, EPSILON);
	return vec3(specular);
}

bool traceWaterSSR(
	vec3 waterViewPosition,
	vec3 surfaceNormal,
	vec3 reflectionDirection,
	out vec2 hitUV,
	out float travelDistance,
	out float hitQuality
) {
	vec3 rayStart = waterViewPosition + surfaceNormal * 0.05;
	vec3 previousRayPosition = rayStart;
	float previousDepthDifference = 0.0;
	bool previousDepthValid = false;
	travelDistance = 0.0;
	hitQuality = 0.0;
	hitUV = vec2(0.0);

	for (int stepIndex = 0; stepIndex < SSR_MAX_STEPS; ++stepIndex) {
		float stepFraction = float(stepIndex) /
			float(SSR_MAX_STEPS - 1);
		float progressiveStep = mix(
			0.15,
			1.35,
			pow(stepFraction, 0.42)
		);
		float depthAdaptiveMultiplier = previousDepthValid ? mix(
			0.90,
			1.06,
			smoothstep(0.02, 0.70, abs(previousDepthDifference))
		) : 1.0;
		float currentStepLength = clamp(
			progressiveStep * depthAdaptiveMultiplier,
			0.10,
			1.35
		);
		travelDistance += min(
			currentStepLength,
			SSR_MAX_DISTANCE - travelDistance
		);
		if (travelDistance >= SSR_MAX_DISTANCE) {
			break;
		}

		vec3 rayPosition = rayStart + reflectionDirection * travelDistance;
		vec2 rayUV;
		if (!projectToScreen(rayPosition, rayUV)) {
			break;
		}

		float sceneDepth = texture(depthtex1, rayUV).r;
		if (sceneDepth >= 0.999999) {
			previousDepthValid = false;
			previousRayPosition = rayPosition;
			continue;
		}

		vec3 sceneViewPosition = reconstructViewPosition(rayUV, sceneDepth);
		float depthDifference = rayPosition.z - sceneViewPosition.z;

		if (previousDepthValid && previousDepthDifference > 0.0 &&
			depthDifference <= 0.0) {
			vec3 nearRayPosition = previousRayPosition;
			vec3 farRayPosition = rayPosition;
			for (int refineIndex = 0;
				refineIndex < SSR_REFINEMENT_STEPS;
				++refineIndex
			) {
				vec3 middleRayPosition = (nearRayPosition + farRayPosition) * 0.5;
				vec2 middleUV;
				if (!projectToScreen(middleRayPosition, middleUV)) {
					break;
				}
				float middleDepth = texture(depthtex1, middleUV).r;
				if (middleDepth >= 0.999999) {
					nearRayPosition = middleRayPosition;
					continue;
				}
				float middleDifference = middleRayPosition.z -
					reconstructViewPosition(middleUV, middleDepth).z;
				if (middleDifference > 0.0) {
					nearRayPosition = middleRayPosition;
				} else {
					farRayPosition = middleRayPosition;
				}
			}

			if (projectToScreen(farRayPosition, hitUV)) {
				float hitDepth = texture(depthtex1, hitUV).r;
				if (hitDepth < 0.999999) {
					float hitDifference = farRayPosition.z -
						reconstructViewPosition(hitUV, hitDepth).z;
					float hitThickness = clamp(
						currentStepLength * 1.25 + travelDistance * 0.004,
						0.06,
						0.55
					);
					if (abs(hitDifference) <= hitThickness) {
						travelDistance = length(farRayPosition - rayStart);
						hitQuality = 1.0 - smoothstep(
							hitThickness * 0.25,
							hitThickness,
							abs(hitDifference)
						);
						return true;
					}
				}
			}
		}

		previousRayPosition = rayPosition;
		previousDepthDifference = depthDifference;
		previousDepthValid = true;
	}

	return false;
}

void main() {
	if (DEBUG_OPAQUE_SCENE) {
		color = texture(colortex5, texcoord);
		return;
	}

	vec4 scene = texture(colortex0, texcoord);
	vec4 waterData = texture(colortex4, texcoord);
	float waterMask = getNearestWaterMask(texcoord);
	if (waterMask < 0.5 || isEyeInWater != 0) {
		color = scene;
		return;
	}

	bool centerHasHand = hasHandAtUV(texcoord);
	vec3 waterViewPosition;
	vec3 opaqueViewPosition;
	float opaqueDepth;
	bool frontmostWater = isFrontmostWaterAtUV(
		texcoord,
		waterViewPosition,
		opaqueViewPosition,
		opaqueDepth
	);
	if (DEBUG_WATER_FRONTMOST_VALIDITY) {
		vec3 validityColor = frontmostWater && !centerHasHand ?
			vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		if (centerHasHand) {
			validityColor = vec3(1.0, 0.0, 1.0);
		}
		color = vec4(validityColor, 1.0);
		return;
	}
	if (DEBUG_HAND_REJECTION) {
		color = vec4(centerHasHand ? vec3(1.0, 0.0, 1.0) : vec3(0.0), 1.0);
		return;
	}
	if (!frontmostWater || centerHasHand) {
		color = scene;
		return;
	}

	vec3 waterNormal = normalize(waterData.rgb * 2.0 - 1.0);
	vec3 viewDirection = normalize(-waterViewPosition);
	if (dot(waterNormal, viewDirection) < 0.0) {
		waterNormal = -waterNormal;
	}
	vec3 upViewNormal = normalize(upPosition);
	float topSurfaceMask = smoothstep(
		0.55,
		0.90,
		dot(waterNormal, upViewNormal)
	);
	vec3 reflectionNormal = waterNormal;
	vec3 refractionNormal = normalize(mix(
		upViewNormal,
		waterNormal,
		mix(1.0, 0.35, topSurfaceMask)
	));
	vec3 fresnelNormal = normalize(mix(
		upViewNormal,
		waterNormal,
		mix(1.0, 0.58, topSurfaceMask)
	));
	const float WATER_ROUGHNESS_CLEAR = 0.065;
	float rainFactor = smoothstep(0.0, 1.0, rainStrength);
	float waterRoughness = mix(
		WATER_ROUGHNESS_CLEAR,
		0.15,
		rainFactor
	);

	float waterThickness = 24.0;
	if (opaqueDepth < 0.999999) {
		waterThickness = clamp(
			length(opaqueViewPosition - waterViewPosition),
			0.0,
			24.0
		);
	}
	float shallowFactor = smoothstep(0.5, 2.0, waterThickness);
	float deepFactor = smoothstep(3.0, 10.0, waterThickness);

	const float AIR_TO_WATER_ETA = 1.0 / 1.333;
	vec3 incidentDirection = normalize(waterViewPosition);
	vec3 refractedDirection = refract(
		incidentDirection,
		refractionNormal,
		AIR_TO_WATER_ETA
	);
	float requestedLod = mix(0.0, 1.5, shallowFactor);
	requestedLod = mix(requestedLod, 3.0, deepFactor);
	float centerOpaqueDistance = opaqueDepth >= 0.999999 ?
		24.0 : length(opaqueViewPosition - waterViewPosition);
	vec2 refractedUV = texcoord;
	float refractionContinuity = 0.0;
	if (dot(refractedDirection, refractedDirection) > 0.00001) {
		float refractionDistance = min(0.12 + waterThickness * 0.16, 1.75);
		vec2 candidateUV;
		if (projectToScreen(
			waterViewPosition + refractedDirection * refractionDistance,
			candidateUV
		)) {
			vec3 candidateFrontPosition;
			vec3 candidateOpaquePosition;
			float candidateOpaqueDepth;
			bool candidateIsWater = getNearestWaterMask(candidateUV) > 0.5 &&
				isFrontmostWaterAtUV(
					candidateUV,
					candidateFrontPosition,
					candidateOpaquePosition,
					candidateOpaqueDepth
				);
			if (candidateIsWater && !hasHandAtUV(candidateUV)) {
				refractionContinuity = getRefractionContinuity(
					candidateUV,
					requestedLod,
					centerOpaqueDistance
				) * getScreenEdgeFade(candidateUV);
				refractedUV = mix(
					texcoord,
					candidateUV,
					refractionContinuity
				);
			}
		}
	}
	if (DEBUG_WATER_REFRACTION_LEAK_DIAGNOSTIC) {
		refractedUV = texcoord;
		refractionContinuity = 0.0;
	}

	const vec3 WATER_ABSORPTION = vec3(0.18, 0.070, 0.030);
	const vec3 WATER_SCATTER_COLOR = vec3(0.012, 0.065, 0.085);
	vec3 transmittance = exp(-WATER_ABSORPTION * waterThickness);
	float safeLod = requestedLod * refractionContinuity;
	vec3 refractedScene = textureLod(colortex5, refractedUV, safeLod).rgb;
	vec3 transmissionColor = refractedScene * transmittance +
		WATER_SCATTER_COLOR * (vec3(1.0) - transmittance);

	const float WATER_F0 = 0.02037;
	float NoV = clamp(dot(fresnelNormal, viewDirection), 0.0, 1.0);
	float fresnel = WATER_F0 + (1.0 - WATER_F0) * pow(1.0 - NoV, 5.0);

	vec3 reflectionDirection = normalize(
		reflect(incidentDirection, reflectionNormal)
	);
	float skyUp = clamp(dot(reflectionDirection, normalize(upPosition)), 0.0, 1.0);
	vec3 reflectedSky = mix(fogColor, skyColor,
		smoothstep(0.0, 0.75, skyUp));
	vec2 screenSkyUV = vec2(0.0);
	bool hasScreenSky = projectViewDirectionToScreen(
		reflectionDirection,
		screenSkyUV
	);
	vec3 screenSkyColor = reflectedSky;
	float screenSkyConfidence = 0.0;
	if (hasScreenSky) {
		float screenSkyDepth = texture(depthtex1, screenSkyUV).r;
		hasScreenSky = screenSkyDepth >= 0.999999 &&
			!hasHandAtUV(screenSkyUV);
		if (hasScreenSky) {
			screenSkyColor = textureLod(colortex5, screenSkyUV, 0.0).rgb;
			screenSkyConfidence = getScreenEdgeFade(screenSkyUV);
		}
	}
	vec3 skyReflection = mix(
		reflectedSky,
		screenSkyColor,
		screenSkyConfidence
	);

	vec2 hitUV = vec2(0.0);
	float travelDistance = 0.0;
	float ssrHitQuality = 0.0;
	bool hitFound = traceWaterSSR(
		waterViewPosition,
		reflectionNormal,
		reflectionDirection,
		hitUV,
		travelDistance,
		ssrHitQuality
	);
	bool ssrHitHand = hitFound && hasHandAtUV(hitUV);
	float ssrLod = 0.0;
	vec3 ssrColor = skyReflection;
	if (hitFound && !ssrHitHand) {
		ssrLod = clamp(
			0.05 +
			0.55 * clamp(travelDistance / SSR_MAX_DISTANCE, 0.0, 1.0) +
			smoothstep(WATER_ROUGHNESS_CLEAR, 0.15, waterRoughness) * 0.65,
			0.0,
			1.30
		);
		ssrLod *= getSsrDepthContinuity(hitUV, ssrLod);
		ssrColor = textureLod(colortex5, hitUV, ssrLod).rgb;
	}
	float edgeFade = hitFound ? getScreenEdgeFade(hitUV) : 0.0;
	float distanceFade = 1.0 - smoothstep(
		SSR_MAX_DISTANCE * 0.70,
		SSR_MAX_DISTANCE,
		travelDistance
	);
	float grazingFade = smoothstep(0.005, 0.035, NoV);
	float ssrConfidence = hitFound && !ssrHitHand ?
		edgeFade * ssrHitQuality * distanceFade * grazingFade : 0.0;
	vec3 environmentReflection = mix(
		skyReflection,
		ssrColor,
		ssrConfidence
	);
	vec3 lightDirection = normalize(shadowLightPosition);
	float solarHeight = sin(sunAngle * 6.28318530718);
	float dayFactor = smoothstep(-0.08, 0.12, solarHeight);
	vec3 directSpecular = calculateWaterDirectSpecular(
		reflectionNormal,
		viewDirection,
		lightDirection,
		waterRoughness
	);
	vec3 sunSpecularTint = vec3(1.00, 0.88, 0.68);
	vec3 moonSpecularTint = vec3(0.38, 0.50, 0.74);
	vec3 directSpecularTint = mix(
		moonSpecularTint,
		sunSpecularTint,
		dayFactor
	);
	float directSpecularStrength = mix(0.08, 1.15, dayFactor) *
		mix(1.0, 0.42, rainFactor);
	vec3 boundedDirectSpecular = min(
		directSpecular * directSpecularTint * directSpecularStrength,
		vec3(1.65)
	);

	if (DEBUG_WATER_NORMAL) {
		color = vec4(waterNormal * 0.5 + 0.5, 1.0);
		return;
	}
	if (DEBUG_WATER_REFRACTION_NORMAL) {
		color = vec4(refractionNormal * 0.5 + 0.5, 1.0);
		return;
	}
	if (DEBUG_WATER_REFLECTION_NORMAL) {
		color = vec4(reflectionNormal * 0.5 + 0.5, 1.0);
		return;
	}
	if (DEBUG_REFRACTION_CONTINUITY) {
		color = vec4(vec3(refractionContinuity), 1.0);
		return;
	}
	if (DEBUG_SAFE_REFRACTION_LOD) {
		color = vec4(vec3(safeLod / 3.0), 1.0);
		return;
	}
	if (DEBUG_WATER_ROUGHNESS) {
		color = vec4(vec3(waterRoughness / 0.15), 1.0);
		return;
	}
	if (DEBUG_WATER_SPECULAR) {
		color = vec4(boundedDirectSpecular / 1.65, 1.0);
		return;
	}
	if (DEBUG_WATER_TRANSMISSION_LOD) {
		color = vec4(vec3(safeLod / 3.0), 1.0);
		return;
	}
	if (DEBUG_WATER_THICKNESS) {
		color = vec4(vec3(waterThickness / 24.0), 1.0);
		return;
	}
	if (DEBUG_WATER_REFRACTION) {
		color = vec4(refractedScene, 1.0);
		return;
	}
	if (DEBUG_WATER_FRESNEL) {
		color = vec4(vec3(fresnel), 1.0);
		return;
	}
	if (DEBUG_WATER_SSR) {
		color = vec4(vec3(ssrConfidence), 1.0);
		return;
	}
	if (DEBUG_SSR_BINARY_HIT) {
		color = vec4(vec3(hitFound && !ssrHitHand ? 1.0 : 0.0), 1.0);
		return;
	}
	if (DEBUG_SSR_HIT_DISTANCE) {
		color = vec4(vec3(travelDistance / SSR_MAX_DISTANCE), 1.0);
		return;
	}
	if (DEBUG_SSR_RAW_COLOR) {
		color = vec4(hitFound && !ssrHitHand ? ssrColor : vec3(0.0), 1.0);
		return;
	}
	if (DEBUG_SSR_CONFIDENCE_COMPONENTS) {
		float ssrValidity = hitFound && !ssrHitHand ? 1.0 : 0.0;
		color = vec4(
			vec3(
				edgeFade,
				ssrHitQuality,
				distanceFade * grazingFade
			) * ssrValidity,
			1.0
		);
		return;
	}
	if (DEBUG_REFLECTION_WEIGHT) {
		float reflectionWeight = clamp(
			fresnel * mix(1.15, 1.0, fresnel),
			0.0,
			0.98
		);
		color = vec4(vec3(reflectionWeight), 1.0);
		return;
	}
	if (DEBUG_SCREEN_SKY_REFLECTION) {
		color = vec4(skyReflection, 1.0);
		return;
	}
	if (DEBUG_DIRECT_SPECULAR_FINAL) {
		color = vec4(boundedDirectSpecular, 1.0);
		return;
	}

	float reflectionWeight = clamp(
		fresnel * mix(1.15, 1.0, fresnel),
		0.0,
		0.98
	);
	vec3 result = mix(
		transmissionColor,
		environmentReflection,
		reflectionWeight
	);
	result += boundedDirectSpecular;
	color = vec4(result, scene.a);
}
