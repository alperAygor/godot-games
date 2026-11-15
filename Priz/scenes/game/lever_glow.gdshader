// Priz aşama 3 — ana şalter "hazır" parıltısı (malzeme üst katmanı): tüm cihazlar takılınca kol sıcak bir
// kenar ışığıyla nabız atar, oyuncu onu çekmesi gerektiğini yazısız anlar. Hazır değilken katman takılmaz.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.3, 1.0);
uniform float strength = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float pulse = 0.55 + 0.45 * sin(TIME * 4.2);
	ALBEDO = glow_color.rgb * (0.45 + rim * 2.2) * pulse * strength;
}
