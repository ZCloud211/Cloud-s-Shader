#version 330 compatibility

uniform sampler2D colortex2;

in vec2 texcoord;

/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 bloomColor;

vec2 getSafeUV(vec2 offset, vec2 halfTexel) {
	return clamp(texcoord + offset, halfTexel, vec2(1.0) - halfTexel);
}

vec3 sampleBloom(vec2 offset, vec2 halfTexel) {
	return texture(colortex2, getSafeUV(offset, halfTexel)).rgb;
}

void main() {
	vec2 bloomSize = vec2(textureSize(colortex2, 0));
	vec2 texelSize = 1.0 / bloomSize;
	vec2 halfTexel = texelSize * 0.5;
	vec2 sampleOffset = vec2(texelSize.x, 0.0);

	vec3 bloom = sampleBloom(vec2(0.0), halfTexel) * 0.227027;
	bloom += (sampleBloom(sampleOffset, halfTexel) + sampleBloom(-sampleOffset, halfTexel)) * 0.1945946;
	bloom += (sampleBloom(sampleOffset * 2.0, halfTexel) + sampleBloom(-sampleOffset * 2.0, halfTexel)) * 0.1216216;
	bloom += (sampleBloom(sampleOffset * 3.0, halfTexel) + sampleBloom(-sampleOffset * 3.0, halfTexel)) * 0.0540540;
	bloom += (sampleBloom(sampleOffset * 4.0, halfTexel) + sampleBloom(-sampleOffset * 4.0, halfTexel)) * 0.0162160;

	bloomColor = vec4(bloom, 1.0);
}
