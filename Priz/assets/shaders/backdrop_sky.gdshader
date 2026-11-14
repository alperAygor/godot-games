// Priz — diorama arka fonu: dikey yumuşak degrade + odanın arkasında hafif hale.
// Arka plan olarak çizilir ve metal/cam yansımalarına yumuşak bir ortam verir.
shader_type sky;
render_mode use_debanding;

uniform vec4 top_color : source_color = vec4(0.82, 0.8, 0.76, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.55, 0.52, 0.5, 1.0);
uniform vec4 halo_color : source_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform float halo_strength = 0.25;
uniform vec3 halo_dir = vec3(-0.6, -0.35, -0.7);

void sky() {
	float h = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(bottom_color.rgb, top_color.rgb, smoothstep(0.08, 0.62, h));
	float d = max(dot(normalize(EYEDIR), normalize(halo_dir)), 0.0);
	col += halo_color.rgb * pow(d, 6.0) * halo_strength;
	COLOR = col;
}
