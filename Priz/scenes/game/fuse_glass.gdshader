// Priz aşama 3 — cam kartuş sigorta (MultiMesh; örnek başına INSTANCE_CUSTOM.r = yanık 0..1, .g = parlama 0..1).
// Sağlam: berrak cam, ortada ince parlak tel. Yanık: is kaplı koyu cam, tel ortadan kopuk, uçlarında kor.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 glass_color : source_color = vec4(0.82, 0.9, 0.95, 1.0);
uniform vec4 soot_color : source_color = vec4(0.06, 0.05, 0.045, 1.0);
uniform vec4 wire_color : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform float power = 1.0;
uniform float half_len = 0.029;

varying float v_burnt;
varying float v_flash;
varying vec3 v_local;

void vertex() {
	v_burnt = INSTANCE_CUSTOM.r;
	v_flash = INSTANCE_CUSTOM.g;
	v_local = VERTEX;
}

void fragment() {
	// Silindir yerel ekseni Y (CylinderMesh); tel ekseni boyunca, kameraya bakan yüzde ince şerit.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float along = v_local.y / half_len;  // -1..1
	float wire = smoothstep(0.93, 0.985, facing);
	// Yanık tel: ortada kopukluk + uçlarda erimiş damla
	float gapw = 0.28 * v_burnt;
	wire *= mix(1.0, smoothstep(gapw, gapw + 0.08, abs(along)), step(0.01, v_burnt));
	float fres = pow(1.0 - facing, 3.0);
	vec3 glass = mix(glass_color.rgb * 0.35, soot_color.rgb, v_burnt);
	float alpha = mix(0.32 + 0.5 * fres, 0.92, v_burnt);
	vec3 alb = mix(glass, wire_color.rgb * 0.6, wire * (1.0 - v_burnt * 0.6));
	ALBEDO = alb;
	ALPHA = clamp(max(alpha, wire), 0.0, 1.0);
	ROUGHNESS = mix(0.05, 0.75, v_burnt);
	SPECULAR = 0.8;
	float glow = wire * (1.0 - v_burnt) * 0.9 * power;
	float scorch = (1.0 - smoothstep(0.0, 0.5, abs(along))) * v_burnt * (1.0 - smoothstep(0.85, 1.0, facing));
	EMISSION = wire_color.rgb * glow + vec3(1.0, 0.35, 0.1) * v_flash * 6.0 + vec3(0.9, 0.25, 0.05) * scorch * 0.15 * v_flash;
}
