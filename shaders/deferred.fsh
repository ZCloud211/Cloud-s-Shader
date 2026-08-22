#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

/* const int colortex5Format = RGBA8; */
const vec4 colortex5ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 sceneColor;
layout(location = 1) out vec4 opaqueSceneColor;

void main() {
	vec4 opaqueScene = texture(colortex0, texcoord);
	sceneColor = opaqueScene;
	opaqueSceneColor = opaqueScene;
}
