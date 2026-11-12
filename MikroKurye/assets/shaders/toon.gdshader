shader_type spatial;
// Stil A: üç bant hücre gölgelendirme + rim. Kaynak: assets/shaders/style_lab/toon.gdshader.
// Oyun için temizlendi: her rol rengini `base_color` parametresiyle alır, ahşap için
// isteğe bağlı prosedürel damar eklenir (doku dosyası gerekmez).
render_mode specular_disabled, ambient_light_disabled;

uniform vec4 base_color : source_color = vec4(0.93, 0.62, 0.18, 1.0);
// Model v2: köşe rengi (alt koyu / üst açık gradyan + pişirilmiş AO) tabanla çarpılır. 0 = kapalı.
uniform float vertex_color_strength : hint_range(0.0, 1.0) = 0.0;
// Gölge zemini rengi: gerçek düşen gölgenin içinde paleti korur (stil A: 44446b).
uniform vec4 shadow_color : source_color = vec4(0.267, 0.267, 0.42, 1.0);
uniform float middle_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float bright_threshold : hint_range(0.0, 1.0) = 0.70;
uniform float middle_level : hint_range(0.0, 1.0) = 0.48;
// Bant kenarı yumuşatma: geçişin yarım genişliği ekran pikseli cinsinden.
// 1.0 ≈ tek piksel geçiş; keskin merdiveni kaldırır, toon bantlarını korur.
uniform float band_smoothness : hint_range(0.0, 8.0) = 1.0;
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
	ALBEDO = base_color.rgb * mix(vec3(1.0), COLOR.rgb, vertex_color_strength);
	if (wood_grain) {
		// Sıfır doku örneği; gölge içinde de damar okunsun diye ALBEDO'dan önce uygulanır.
		// Kalaslar UV.x boyunca ayrılır: kalas kenarında ince koyu çizgi, kalas içinde
		// ince damar, kalas başına hafif ton farkı (deterministik).
		float plank_uv = UV.x * wood_freq;
		float plank_id = floor(plank_uv);
		float within = fract(plank_uv);
		// Kalas başına ton farkı merkezlenir: bazı kalaslar hafif açık, bazıları koyu.
		float tone = fract(sin(plank_id * 127.1 + 311.7) * 43758.5453) - 0.5;
		float grain = sin(within * 6.2831853 * 5.0 + sin(UV.y * 6.2831853) * wood_wobble);
		float seam = (1.0 - smoothstep(0.0, 0.1, within))
			+ (1.0 - smoothstep(0.9, 1.0, within));
		float darken = wood_strength * (0.7 * seam + 0.3 * (grain * 0.5 + 0.5));
		ALBEDO = mix(ALBEDO, wood_dark.rgb, clamp(darken, 0.0, 1.0));
		ALBEDO *= 1.0 + tone * 0.35;
	}
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = ALBEDO * shadow_color.rgb + rim_color.rgb * rim * rim_strength;
	EMISSION += emissive_color.rgb * emissive_energy;
}

void light() {
	float illumination = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	// Ekran-türevi tabanlı yarım genişlik: bant sınırı her çözünürlükte ~1px
	// yumuşak geçer. Keskin `step` merdiven üretiyordu; smoothstep araya geçiş
	// pikselleri koyarak tırtığı bitirir (stil A üç bant kimliği korunur).
	float edge = fwidth(illumination) * band_smoothness;
	float band = mix(0.0, middle_level,
		smoothstep(middle_threshold - edge, middle_threshold + edge, illumination));
	band = mix(band, 1.0,
		smoothstep(bright_threshold - edge, bright_threshold + edge, illumination));
	DIFFUSE_LIGHT += (vec3(1.0) - shadow_color.rgb) * band * LIGHT_COLOR / PI;
}
