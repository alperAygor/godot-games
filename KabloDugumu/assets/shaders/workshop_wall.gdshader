shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

// Atölye arka duvarı (AmbientBackdrop): tek geçiş, doku yok, TIME yok.
// Sıcak-koyu ASMR paleti: koyu sıcak gri zemin + tepede asma lambanın sıcak
// havuzu + dikey panel dikişleri. Pano arkasında kaldığı için maliyeti düşük.

uniform vec4 base_color : source_color = vec4(0.052, 0.050, 0.058, 1.0);
uniform vec4 warm_color : source_color = vec4(0.30, 0.19, 0.10, 1.0);
uniform vec2 lamp_center = vec2(0.52, 0.78);
uniform float lamp_radius : hint_range(0.05, 1.5) = 0.62;
uniform float seam_strength : hint_range(0.0, 0.3) = 0.045;

void fragment() {
	vec2 uv = UV;
	vec3 color = base_color.rgb;

	// Tepeden alta doğru hafif ısınan gradyan (lamba ışığı duvara vurur).
	float vertical = clamp(1.0 - uv.y, 0.0, 1.0);
	color += warm_color.rgb * vertical * 0.16;

	// Asma lambanın sıcak havuzu.
	float distance_to_lamp = distance(vec2(uv.x, 1.0 - uv.y), lamp_center);
	float pool = smoothstep(lamp_radius, 0.0, distance_to_lamp);
	color += warm_color.rgb * pool * 0.52;

	// Büyük metal plaka dikişleri (çok hafif koyu çizgiler).
	vec2 plates = uv * vec2(5.0, 6.0);
	vec2 seam_distance = abs(fract(plates) - 0.5);
	float seam = smoothstep(0.46, 0.5, max(seam_distance.x, seam_distance.y));
	color *= 1.0 - seam * seam_strength;

	// Köşelerde yumuşak sönüm: duvarın sınırı asla "kesik" görünmesin.
	float edge = smoothstep(0.0, 0.18, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	color *= mix(0.72, 1.0, edge);

	ALBEDO = color;
}
