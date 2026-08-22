#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

in vec2 texcoord;

layout(location = 0) out vec4 color;

const float BLOOM_NEAR_WEIGHT = 0.62;
const float BLOOM_WIDE_WEIGHT = 0.38;
const float BLOOM_RESPONSE = 0.16;

vec3 sampleBilinear(sampler2D textureSampler, vec2 uv) {
	ivec2 textureSizePixels = textureSize(textureSampler, 0);
	vec2 texelPosition = uv * vec2(textureSizePixels) - 0.5;
	ivec2 baseTexel = ivec2(floor(texelPosition));
	vec2 fractionPart = fract(texelPosition);
	ivec2 maxTexel = textureSizePixels - ivec2(1);

	vec3 sample00 = texelFetch(textureSampler, clamp(baseTexel, ivec2(0), maxTexel), 0).rgb;
	vec3 sample10 = texelFetch(textureSampler, clamp(baseTexel + ivec2(1, 0), ivec2(0), maxTexel), 0).rgb;
	vec3 sample01 = texelFetch(textureSampler, clamp(baseTexel + ivec2(0, 1), ivec2(0), maxTexel), 0).rgb;
	vec3 sample11 = texelFetch(textureSampler, clamp(baseTexel + ivec2(1, 1), ivec2(0), maxTexel), 0).rgb;

	return mix(mix(sample00, sample10, fractionPart.x),
		mix(sample01, sample11, fractionPart.x), fractionPart.y);
}

void main() {
	vec4 scene = texture(colortex0, texcoord);
	vec3 nearBloom = sampleBilinear(colortex1, texcoord);
	vec3 wideBloom = sampleBilinear(colortex2, texcoord);
	vec3 bloom = nearBloom * BLOOM_NEAR_WEIGHT + wideBloom * BLOOM_WIDE_WEIGHT;
	vec3 bloomResponse = vec3(1.0) - exp(-bloom * BLOOM_RESPONSE);
	vec3 result = scene.rgb + (vec3(1.0) - scene.rgb) * bloomResponse;
	result = clamp(result, 0.0, 1.0);
	color = vec4(result, scene.a);
}
