// Gentle global color grading for a more natural, photographic look.
const float colorExposure = 1.05;
const float colorSaturation = 0.92;
const float colorContrast = 1.03;

vec3 acesToneMap(vec3 color) {
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;
	return (color * (a * color + b)) / (color * (c * color + d) + e);
}

vec3 applyColorGrade(vec3 srgbColor) {
	// colortex0 stores display-referred sRGB colors, so grade in linear space.
	vec3 color = pow(max(srgbColor, vec3(0.0)), vec3(2.2));
	color *= colorExposure;
	color = acesToneMap(color);

	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luminance), color, colorSaturation);
	color = (color - 0.5) * colorContrast + 0.5;

	return pow(clamp(color, 0.0, 1.0), vec3(1.0 / 2.2));
}
