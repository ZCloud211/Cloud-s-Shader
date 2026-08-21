// Radial shadow-map distortion: more resolution near the player, less at the edges.
const int shadowMapResolution = 2048;
const float shadowDistanceRenderMul = 1.0;
const bool shadowtex0Nearest = true;

// Keep the distortion moderate to avoid over-stretching block side faces.
const float shadowDistortionStrength = 0.40;

vec3 distortShadowClipPos(vec3 shadowClipPosition) {
	float distortionRadius = length(shadowClipPosition.xy) + 0.1;
	float distortionFactor = mix(1.0, distortionRadius, shadowDistortionStrength);
	shadowClipPosition.xy /= distortionFactor;

	// Extend depth range slightly when the sun is low on the horizon.
	shadowClipPosition.z *= 0.5;
	return shadowClipPosition;
}
