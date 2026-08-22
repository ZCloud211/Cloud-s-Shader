#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;
uniform float frameTimeCounter;
uniform mat4 gbufferModelView;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 worldPosition;
flat in float blockId;

/* const int colortex4Format = RGBA8; */
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 waterData;

void main() {
	vec4 baseWater = texture(gtexture, texcoord) * glcolor;
	if (baseWater.a < alphaTestRef) {
		discard;
	}
	baseWater.rgb *= texture(lightmap, lmcoord).rgb;
	color = baseWater;

	bool isWater = abs(blockId - 10091.0) < 0.5;
	if (!isWater) {
		waterData = vec4(0.0);
		return;
	}

	vec2 direction1 = normalize(vec2(0.80, 0.60));
	vec2 direction2 = normalize(vec2(-0.60, 0.80));
	vec2 direction3 = normalize(vec2(0.30, -0.95));
	float phase1 = dot(worldPosition.xz, direction1) * 0.85 +
		frameTimeCounter * 0.65;
	float phase2 = dot(worldPosition.xz, direction2) * 1.70 +
		frameTimeCounter * -0.90;
	float phase3 = dot(worldPosition.xz, direction3) * 3.20 +
		frameTimeCounter * 1.30;

	float dHeightDx = 0.035 * 0.85 * direction1.x * cos(phase1);
	dHeightDx += 0.018 * 1.70 * direction2.x * cos(phase2);
	dHeightDx += 0.008 * 3.20 * direction3.x * cos(phase3);
	float dHeightDz = 0.035 * 0.85 * direction1.y * cos(phase1);
	dHeightDz += 0.018 * 1.70 * direction2.y * cos(phase2);
	dHeightDz += 0.008 * 3.20 * direction3.y * cos(phase3);

	vec3 worldNormal = normalize(vec3(-dHeightDx, 1.0, -dHeightDz));
	vec3 viewNormal = normalize(mat3(gbufferModelView) * worldNormal);
	vec3 encodedNormal = viewNormal * 0.5 + 0.5;
	waterData = vec4(encodedNormal, 1.0);
}
