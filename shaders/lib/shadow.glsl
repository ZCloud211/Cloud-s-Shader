#include "/lib/shadow_distort.glsl"

uniform sampler2D shadowtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;

uniform float viewWidth;
uniform float viewHeight;

const float shadowBias = 0.0012;
const float shadowSlopeBias = 0.0055;
// Split the final light into direct sun/moon light and a soft environment fill.
// This keeps fully shadowed surfaces readable instead of multiplying them to black.
const float shadowStrength = 0.58;
const float shadowAmbient = 0.42;
const float darkMaterialAmbientLift = 0.16;

vec3 getShadowPosition() {
	vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
	vec3 ndcPosition = vec3(screenUV, gl_FragCoord.z) * 2.0 - 1.0;

	vec4 viewPosition = gbufferProjectionInverse * vec4(ndcPosition, 1.0);
	viewPosition /= viewPosition.w;

	vec3 playerPosition = (gbufferModelViewInverse * viewPosition).xyz;
	vec4 shadowClipPosition = shadowProjection * shadowModelView * vec4(playerPosition, 1.0);

	// Increase the bias on surfaces seen at a grazing angle to prevent acne stripes.
	float lightFacing = abs(dot(normalize(normal), normalize(shadowLightPosition)));
	float slopeBias = shadowBias + shadowSlopeBias * (1.0 - lightFacing);
	shadowClipPosition.z -= slopeBias;
	shadowClipPosition.xyz = distortShadowClipPos(shadowClipPosition.xyz);

	return shadowClipPosition.xyz / shadowClipPosition.w * 0.5 + 0.5;
}

float getShadowFactor(vec3 materialColor, float materialAmbientBoost) {
	vec3 shadowPosition = getShadowPosition();

	// Fragments outside the sun/moon shadow frustum are lit.
	if (shadowPosition.x <= 0.0 || shadowPosition.x >= 1.0 ||
		shadowPosition.y <= 0.0 || shadowPosition.y >= 1.0 ||
		shadowPosition.z <= 0.0 || shadowPosition.z >= 1.0) {
		return 1.0;
	}

	// Darker albedo needs a little more fill light to keep grass and dirt readable.
	float materialLuminance = dot(clamp(materialColor, 0.0, 1.0),
		vec3(0.2126, 0.7152, 0.0722));
	float darkMaterialMask = 1.0 - smoothstep(0.15, 0.60, materialLuminance);
	float materialAmbient = shadowAmbient
		+ darkMaterialMask * darkMaterialAmbientLift
		+ materialAmbientBoost;

	// A small 2x2 filter removes one-pixel stripes without the blur of a 3x3 PCF.
	vec2 texelSize = 1.0 / vec2(textureSize(shadowtex0, 0));
	float shadow = 0.0;
	for (int x = 0; x < 2; x++) {
		for (int y = 0; y < 2; y++) {
			vec2 offset = (vec2(x, y) - 0.5) * texelSize;
			float shadowDepth = texture(shadowtex0, shadowPosition.xy + offset).r;
			shadow += step(shadowPosition.z, shadowDepth);
		}
	}
	shadow *= 0.25;
	return clamp(shadow * shadowStrength + materialAmbient, 0.0, 1.0);
}

float getShadowFactor(vec3 materialColor) {
	return getShadowFactor(materialColor, 0.0);
}
