shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec4 base_color : source_color = vec4(0.19, 0.68, 0.73, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.27, 0.24, 0.53, 1.0);
uniform float light_threshold : hint_range(0.0, 1.0) = 0.42;
uniform float lit_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	// Derivatives recover planar faces even when the source mesh has smooth normals.
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = face_normal * (dot(face_normal, NORMAL) < 0.0 ? -1.0 : 1.0);
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
	EMISSION = base_color.rgb * shadow_color.rgb;
}

void light() {
	float illumination = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float hard_light = step(light_threshold, illumination);
	DIFFUSE_LIGHT += (vec3(1.0) - shadow_color.rgb) * hard_light * lit_strength * LIGHT_COLOR / PI;
}
