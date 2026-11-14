// Priz — fırın iç haznesi. heat arttıkça turuncu bir ışıma; tavana yakın (rezistans) daha sıcak.
// UV.y: 0 alt, 1 üst (Blender'da hazne UV'si buna göre verilir).
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 enamel_color : source_color = vec4(0.10, 0.10, 0.11, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float energy = 3.5;
instance uniform float heat : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float n = texture(noise_tex, UV * 2.0 + vec2(TIME * 0.03, TIME * 0.11)).g;
	float top = smoothstep(0.1, 1.0, UV.y);
	vec3 warm = mix(vec3(1.0, 0.36, 0.08), vec3(1.0, 0.7, 0.35), top * heat);
	ALBEDO = enamel_color.rgb;
	ROUGHNESS = 0.3;
	float shimmer = 0.88 + 0.12 * n;
	EMISSION = warm * heat * (0.35 + 0.65 * top) * energy * shimmer;
}
