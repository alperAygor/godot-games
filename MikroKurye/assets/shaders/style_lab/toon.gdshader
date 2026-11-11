shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec4 base_color : source_color = vec4(0.95, 0.57, 0.19, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.30, 0.25, 0.46, 1.0);
uniform float middle_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float bright_threshold : hint_range(0.0, 1.0) = 0.70;
uniform float middle_level : hint_range(0.0, 1.0) = 0.48;
uniform vec4 rim_color : source_color = vec4(1.0, 0.87, 0.63, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
	// A small colored floor preserves the palette inside actual cast shadows.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = base_color.rgb * shadow_color.rgb + rim_color.rgb * rim * rim_strength;
}

void light() {
	float illumination = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float band = mix(0.0, middle_level, step(middle_threshold, illumination));
	band = mix(band, 1.0, step(bright_threshold, illumination));
	DIFFUSE_LIGHT += (vec3(1.0) - shadow_color.rgb) * band * LIGHT_COLOR / PI;
}
