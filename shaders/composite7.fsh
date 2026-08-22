#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex4;
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

	const float WATER_F0 = 0.02;
	float NoV = clamp(dot(waterNormal, viewDirection), 0.0, 1.0);
	float fresnel = WATER_F0 + (1.0 - WATER_F0) * pow(1.0 - NoV, 5.0);
	float reflectionStrength = mix(0.035, 0.48, fresnel);

	vec3 incidentDirection = normalize(waterViewPosition);
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
	vec3 ssrColor = texture(colortex0, hitUV).rgb;
	float edgeDistance = min(min(hitUV.x, 1.0 - hitUV.x),
		min(hitUV.y, 1.0 - hitUV.y));
	float edgeFade = smoothstep(0.015, 0.08, edgeDistance);
	float distanceFade = 1.0 - clamp(travelDistance / 24.0, 0.0, 1.0);
	float grazingFade = smoothstep(0.03, 0.20, NoV);
	float ssrConfidence = hitFound ? edgeFade * distanceFade * grazingFade : 0.0;
	vec3 reflectionColor = mix(reflectedSky, ssrColor, ssrConfidence);

	float finalReflectionAmount = clamp(reflectionStrength, 0.0, 0.55);
	vec3 result = mix(scene.rgb, reflectionColor, finalReflectionAmount);
	color = vec4(result, scene.a);
}
