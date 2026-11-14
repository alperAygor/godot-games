// Priz — dönen vantilatör kanatlarının hareket bulanıklığı diski. Hız arttıkça görünür olur;
// gerçek kanatlar aynı oranda saydamlaşmaz (geometri hep çizilir), disk yalnız "akış" hissi verir.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;

uniform vec4 blade_color : source_color = vec4(0.66, 0.81, 0.76, 1.0);
instance uniform float speed : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float band = smoothstep(0.12, 0.2, r) * (1.0 - smoothstep(0.82, 0.98, r));
	float ang = atan(d.y, d.x);
	float swirl = 0.85 + 0.15 * sin(ang * 3.0 + TIME * 40.0);
	ALBEDO = blade_color.rgb;
	ROUGHNESS = 0.4;
	ALPHA = band * swirl * speed * 0.42;
}
