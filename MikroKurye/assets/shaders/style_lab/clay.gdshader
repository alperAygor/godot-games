shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec4 base_color : source_color = vec4(0.77, 0.49, 0.34, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.43, 0.35, 0.42, 1.0);
uniform float diffuse_wrap : hint_range(0.0, 1.0) = 0.38;
uniform float gradient_strength : hint_range(0.0, 0.3) = 0.08;
uniform float gradient_bottom = -0.5;
uniform float gradient_top = 0.5;

varying float local_height;

void vertex() {
	local_height = VERTEX.y;
}

void fragment() {
	// Object-space height keeps the gentle color variation attached to each prop.
	float height_blend = smoothstep(gradient_bottom, gradient_top, local_height);
	float gradient = mix(1.0 - gradient_strength, 1.0 + gradient_strength, height_blend);
	ALBEDO = base_color.rgb * gradient;
	ROUGHNESS = 1.0;
	EMISSION = ALBEDO * shadow_color.rgb;
}

void light() {
	float wrapped = clamp((dot(NORMAL, LIGHT) + diffuse_wrap) / (1.0 + diffuse_wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += (vec3(1.0) - shadow_color.rgb) * wrapped * ATTENUATION * LIGHT_COLOR / PI;
}
