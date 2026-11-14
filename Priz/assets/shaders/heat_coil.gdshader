// Priz — ısıtıcı tel (ekmek kızartma makinesi telleri, fırın rezistansı).
// heat 0..1: kara cisim rengi soğuk metalden koyu kırmızıya, oradan turuncu-sarıya.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 cold_color : source_color = vec4(0.32, 0.30, 0.29, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float energy = 6.0;
instance uniform float heat : hint_range(0.0, 1.0) = 0.0;

vec3 blackbody(float t) {
	// t 0..1 → koyu kırmızı → turuncu → sarımsı beyaz
	vec3 a = vec3(0.45, 0.04, 0.0);
	vec3 b = vec3(1.0, 0.32, 0.04);
	vec3 c = vec3(1.0, 0.78, 0.45);
	return t < 0.6 ? mix(a, b, t / 0.6) : mix(b, c, (t - 0.6) / 0.4);
}

void fragment() {
	float n = texture(noise_tex, UV * vec2(1.0, 3.0) + vec2(0.0, TIME * 0.05)).r;
	float h = clamp(heat * (0.85 + 0.3 * n), 0.0, 1.0);
	ALBEDO = mix(cold_color.rgb, vec3(0.2, 0.05, 0.02), h);
	METALLIC = 0.6 * (1.0 - h);
	ROUGHNESS = 0.45;
	float flick = 0.94 + 0.06 * sin(TIME * 9.0 + n * 12.0);
	EMISSION = blackbody(h) * pow(h, 1.6) * energy * flick;
}
