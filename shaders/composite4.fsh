#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const float BLOOM_INTENSITY = 0.08;

void main() {
	vec4 scene = texture(colortex0, texcoord);
	vec3 bloom = texture(colortex1, texcoord).rgb;
	vec3 result = scene.rgb + bloom * BLOOM_INTENSITY;
	color = vec4(result, scene.a);
}
