#version 330 compatibility

uniform sampler2D colortex1;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 bloomColor;

vec2 getSafeUV(vec2 offset) {
	vec2 halfTexel = vec2(0.5 / viewWidth, 0.5 / viewHeight);
	return clamp(texcoord + offset, halfTexel, vec2(1.0) - halfTexel);
}

vec3 sampleBloom(vec2 offset) {
	return texture(colortex1, getSafeUV(offset)).rgb;
}

void main() {
	float radiusScale = clamp(viewHeight / 1080.0, 0.75, 2.0);
	vec2 sampleOffset = vec2(0.0, 1.0 / viewHeight) * radiusScale;

	vec3 bloom = sampleBloom(vec2(0.0)) * 0.227027;
	bloom += (sampleBloom(sampleOffset) + sampleBloom(-sampleOffset)) * 0.1945946;
	bloom += (sampleBloom(sampleOffset * 2.0) + sampleBloom(-sampleOffset * 2.0)) * 0.1216216;
	bloom += (sampleBloom(sampleOffset * 3.0) + sampleBloom(-sampleOffset * 3.0)) * 0.0540540;
	bloom += (sampleBloom(sampleOffset * 4.0) + sampleBloom(-sampleOffset * 4.0)) * 0.0162160;

	bloomColor = vec4(bloom, 1.0);
}
