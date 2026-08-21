#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

#include "/lib/color_grade.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	// Keep the final image neutral. The previous red tint was only a template test.
	vec4 sceneColor = texture(colortex0, texcoord);
	color = vec4(applyColorGrade(sceneColor.rgb), sceneColor.a);
}
