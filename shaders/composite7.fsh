#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 upPosition;

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

vec3 reconstructViewPosition(vec2 screenUV, float depth) {
	vec3 ndcPosition = vec3(screenUV, depth) * 2.0 - 1.0;
	vec4 viewPosition = gbufferProjectionInverse * vec4(ndcPosition, 1.0);
	return viewPosition.xyz / viewPosition.w;
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

float getScreenEdgeFade(vec2 screenUV) {
	float edgeDistance = min(
		min(screenUV.x, 1.0 - screenUV.x),
		min(screenUV.y, 1.0 - screenUV.y)
	);
	return smoothstep(0.015, 0.08, edgeDistance);
}

bool traceWaterSSR(
	vec3 waterViewPosition,
	vec3 waterNormal,
	vec3 reflectionDirection,
	out vec2 hitUV,
	out float travelDistance
) {
	vec3 rayStart = waterViewPosition + waterNormal * 0.05;
	vec3 previousRayPosition = rayStart;
	float previousDepthDifference = 0.0;
	bool previousDepthValid = false;
	travelDistance = 0.0;

	for (int stepIndex = 0; stepIndex < 20; ++stepIndex) {
		float stepFraction = float(stepIndex) / 19.0;
		travelDistance += mix(0.25, 1.25, stepFraction);
		if (travelDistance > 24.0) {
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
		float thickness = mix(0.08, 0.45,
			clamp(travelDistance / 24.0, 0.0, 1.0));

		if (previousDepthValid && previousDepthDifference > 0.0 &&
			depthDifference <= 0.0) {
			vec3 nearRayPosition = previousRayPosition;
			vec3 farRayPosition = rayPosition;
			for (int refineIndex = 0; refineIndex < 3; ++refineIndex) {
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
					if (abs(hitDifference) <= thickness) {
						travelDistance = length(farRayPosition - rayStart);
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
	float waterMask = waterData.a;
	if (waterMask < 0.5 || isEyeInWater != 0) {
		color = scene;
		return;
	}

	float waterDepth = texture(depthtex0, texcoord).r;
	vec3 waterViewPosition = reconstructViewPosition(texcoord, waterDepth);
	vec3 waterNormal = normalize(waterData.rgb * 2.0 - 1.0);
	vec3 viewDirection = normalize(-waterViewPosition);
	if (dot(waterNormal, viewDirection) < 0.0) {
		waterNormal = -waterNormal;
	}

	float opaqueDepth = texture(depthtex1, texcoord).r;
	float waterThickness = 24.0;
	if (opaqueDepth < 0.999999) {
		vec3 opaqueViewPosition = reconstructViewPosition(texcoord, opaqueDepth);
		if (opaqueViewPosition.z < waterViewPosition.z - 0.001) {
			waterThickness = clamp(
				length(opaqueViewPosition - waterViewPosition),
				0.0,
				24.0
			);
		}
	}

	const float AIR_TO_WATER_ETA = 1.0 / 1.333;
	vec3 incidentDirection = normalize(waterViewPosition);
	vec3 refractedDirection = refract(
		incidentDirection,
		waterNormal,
		AIR_TO_WATER_ETA
	);
	vec2 refractedUV = texcoord;
	if (dot(refractedDirection, refractedDirection) > 0.00001) {
		float refractionDistance = min(0.12 + waterThickness * 0.16, 1.75);
		vec2 candidateUV;
		if (projectToScreen(
			waterViewPosition + refractedDirection * refractionDistance,
			candidateUV
		)) {
			float candidateDepth = texture(depthtex1, candidateUV).r;
			bool isSkyBehindWater = candidateDepth >= 0.999999;
			bool isOpaqueBehindWater = false;
			if (!isSkyBehindWater) {
				vec3 candidateViewPosition = reconstructViewPosition(
					candidateUV,
					candidateDepth
				);
				isOpaqueBehindWater =
					candidateViewPosition.z < waterViewPosition.z - 0.001;
			}

			if (isSkyBehindWater || isOpaqueBehindWater) {
				refractedUV = mix(
					texcoord,
					candidateUV,
					getScreenEdgeFade(candidateUV)
				);
			}
		}
	}

	const vec3 WATER_ABSORPTION = vec3(0.18, 0.070, 0.030);
	const vec3 WATER_SCATTER_COLOR = vec3(0.012, 0.065, 0.085);
	vec3 transmittance = exp(-WATER_ABSORPTION * waterThickness);
	vec3 refractedScene = texture(colortex5, refractedUV).rgb;
	vec3 transmissionColor = refractedScene * transmittance +
		WATER_SCATTER_COLOR * (vec3(1.0) - transmittance);

	const float WATER_F0 = 0.02037;
	float NoV = clamp(dot(waterNormal, viewDirection), 0.0, 1.0);
	float fresnel = WATER_F0 + (1.0 - WATER_F0) * pow(1.0 - NoV, 5.0);

	vec3 reflectionDirection = normalize(reflect(incidentDirection, waterNormal));
	float skyUp = clamp(dot(reflectionDirection, normalize(upPosition)), 0.0, 1.0);
	vec3 reflectedSky = mix(fogColor, skyColor,
		smoothstep(0.0, 0.75, skyUp));

	vec2 hitUV = vec2(0.0);
	float travelDistance = 0.0;
	bool hitFound = traceWaterSSR(
		waterViewPosition,
		waterNormal,
		reflectionDirection,
		hitUV,
		travelDistance
	);
	vec3 ssrColor = reflectedSky;
	if (hitFound) {
		ssrColor = texture(colortex5, hitUV).rgb;
	}
	float edgeFade = hitFound ? getScreenEdgeFade(hitUV) : 0.0;
	float distanceFade = 1.0 - clamp(travelDistance / 24.0, 0.0, 1.0);
	float grazingFade = smoothstep(0.03, 0.20, NoV);
	float ssrConfidence = hitFound ? edgeFade * distanceFade * grazingFade : 0.0;
	vec3 reflectionColor = mix(reflectedSky, ssrColor, ssrConfidence);

	if (DEBUG_WATER_NORMAL) {
		color = vec4(waterNormal * 0.5 + 0.5, 1.0);
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

	vec3 result = mix(transmissionColor, reflectionColor, fresnel);
	color = vec4(result, scene.a);
}
