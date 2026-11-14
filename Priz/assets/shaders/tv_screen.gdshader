// Priz — televizyon ekranı. Kapalıyken koyu, yansıtıcı cam. Açıkken tablo atlasından
// yavaşça kayan, birbirine karışan "sahneler" (yazı/rakam yok). Işık rengi betikte aynı
// paletten hesaplanır (tv_fx.gd).
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D art_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float energy = 2.2;
instance uniform float power : hint_range(0.0, 1.0) = 0.0;
instance uniform float scene_a = 0.0;
instance uniform float scene_b = 1.0;
instance uniform float scene_mix : hint_range(0.0, 1.0) = 0.0;
instance uniform float pan = 0.0;

vec3 sample_scene(float idx, vec2 uv) {
	float i = mod(idx, 4.0);
	vec2 cell = vec2(mod(i, 2.0), floor(i / 2.0)) * 0.5;
	// Yavaş "kamera hareketi": hafif yakınlaşma ve kaydırma.
	vec2 p = (uv - 0.5) * (0.82 - 0.06 * sin(pan * 0.7 + idx)) + 0.5;
	p.x += 0.05 * sin(pan * 0.5 + idx * 1.7);
	p = clamp(p, 0.02, 0.98);
	return textureLod(art_tex, cell + p * 0.5, 1.2).rgb;
}

void fragment() {
	vec2 uv = UV;
	vec3 a = sample_scene(scene_a, uv);
	vec3 b = sample_scene(scene_b, uv);
	vec3 img = mix(a, b, smoothstep(0.0, 1.0, scene_mix));
	// İnce satır deseni ve köşe kararması (gerçek panel hissi)
	float lines = 0.94 + 0.06 * sin(uv.y * 900.0);
	vec2 d = uv - 0.5;
	float vig = 1.0 - dot(d, d) * 1.1;
	float on = smoothstep(0.0, 1.0, power);
	ALBEDO = mix(vec3(0.015, 0.016, 0.02), vec3(0.0), on);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	EMISSION = img * lines * vig * energy * on;
}
