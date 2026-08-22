#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
flat in float blockId;

/* const int colortex3Format = RGBA16F; */
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 materialData;

vec3 getVisibleEmission(vec3 emissionRadiance) {
	float peakRadiance = max(
		emissionRadiance.r,
		max(emissionRadiance.g, emissionRadiance.b)
	);

	if (peakRadiance <= 0.00001) {
		return vec3(0.0);
	}

	vec3 chromaticity = emissionRadiance / peakRadiance;
	const float EMISSION_DISPLAY_EXPOSURE = 0.55;
	float visibleIntensity =
		1.0 - exp(-peakRadiance * EMISSION_DISPLAY_EXPOSURE);

	return chromaticity * visibleIntensity;
}

void main() {
	vec4 albedo = texture(gtexture, texcoord) * glcolor;
	if (albedo.a < alphaTestRef) {
		discard;
	}

	vec3 lightValue = texture(lightmap, lmcoord).rgb;
	vec3 litColor = albedo.rgb * lightValue;
	float blockLight = clamp(lmcoord.x, 0.0, 1.0);

	bool strongEmitter = abs(blockId - 10089.0) < 0.5;
	bool smallEmitter = abs(blockId - 10090.0) < 0.5;
	float textureBrightness = max(albedo.r, max(albedo.g, albedo.b));
	float emissionRadianceScale = 0.0;
	if (strongEmitter) {
		emissionRadianceScale = 2.40;
	} else if (smallEmitter) {
		emissionRadianceScale =
			1.60 * smoothstep(0.42, 0.82, textureBrightness);
	}

	vec3 emissionRadiance = albedo.rgb * emissionRadianceScale;
	vec3 visibleEmission = getVisibleEmission(emissionRadiance);
	vec3 surfaceColor = max(litColor, visibleEmission);
	color = vec4(surfaceColor, albedo.a);
	materialData = vec4(emissionRadiance, blockLight);
}
