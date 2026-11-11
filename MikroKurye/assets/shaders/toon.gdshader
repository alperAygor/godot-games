shader_type spatial;
// Stil A: üç bant hücre gölgelendirme + rim. Kaynak: assets/shaders/style_lab/toon.gdshader.
// Oyun için temizlendi: her rol rengini `base_color` parametresiyle alır, ahşap için
// isteğe bağlı prosedürel damar eklenir (doku dosyası gerekmez).
render_mode specular_disabled, ambient_light_disabled;

uniform vec4 base_color : source_color = vec4(0.93, 0.62, 0.18, 1.0);
// Gölge zemini rengi: gerçek düşen gölgenin içinde paleti korur (stil A: 44446b).
uniform vec4 shadow_color : source_color = vec4(0.267, 0.267, 0.42, 1.0);
uniform float middle_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float bright_threshold : hint_range(0.0, 1.0) = 0.70;
uniform float middle_level : hint_range(0.0, 1.0) = 0.48;
uniform vec4 rim_color : source_color = vec4(1.0, 0.87, 0.63, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;

// Ahşap damarı: yalnız masa malzemelerinde açılır. UV.x boyunca sık çizgiler +
// UV.y ile yavaş kıvrılma, kutu yüzeylerinde plank görünümü verir.
uniform bool wood_grain = false;
uniform vec4 wood_dark : source_color = vec4(0.69, 0.48, 0.27, 1.0);
uniform float wood_freq : hint_range(1.0, 60.0) = 16.0;
uniform float wood_wobble : hint_range(0.0, 4.0) = 1.6;
uniform float wood_strength : hint_range(0.0, 1.0) = 0.35;

// İsteğe bağlı emisyon: Altın Kutu gibi kendi kendine parlayan nesnelerde açılır.
// Enerji > 1.0 HDR üretip bloom eşiğini aşar; diğer malzemelerde 0 kalır.
uniform vec4 emissive_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emissive_energy : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	ALBEDO = base_color.rgb;
	if (wood_grain) {
		// Sıfır doku örneği; gölge içinde de damar okunsun diye ALBEDO'dan önce uygulanır.
		float streak = sin(UV.x * wood_freq + sin(UV.y * 6.2831853) * wood_wobble);
		ALBEDO = mix(ALBEDO, wood_dark.rgb, (streak * 0.5 + 0.5) * wood_strength);
	}
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = ALBEDO * shadow_color.rgb + rim_color.rgb * rim * rim_strength;
	EMISSION += emissive_color.rgb * emissive_energy;
}

void light() {
	float illumination = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float band = mix(0.0, middle_level, step(middle_threshold, illumination));
	band = mix(band, 1.0, step(bright_threshold, illumination));
	DIFFUSE_LIGHT += (vec3(1.0) - shadow_color.rgb) * band * LIGHT_COLOR / PI;
}
