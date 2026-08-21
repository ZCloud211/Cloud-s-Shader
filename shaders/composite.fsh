#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	// Keep the final image neutral. The previous red tint was only a template test.
	color = texture(colortex0, texcoord);
}
