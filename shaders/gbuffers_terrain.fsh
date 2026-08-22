#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
flat in float blockId;

/* const int colortex3Format = RGBA8; */
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 materialData;

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
	float emissionStrength = 0.0;
	if (strongEmitter) {
		emissionStrength = 1.0;
	} else if (smallEmitter) {
		emissionStrength = 0.75 * smoothstep(0.42, 0.82, textureBrightness);
	}

	vec3 emissionColor = albedo.rgb * emissionStrength;
	vec3 surfaceColor = max(litColor, emissionColor);
	color = vec4(surfaceColor, albedo.a);
	materialData = vec4(clamp(emissionColor, 0.0, 1.0), blockLight);
}
