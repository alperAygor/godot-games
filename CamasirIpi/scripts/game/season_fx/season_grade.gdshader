shader_type canvas_item;

// Mevsim renk derecelendirmesi (SeasonLook verisi, data/seasons.json). Neden gölgelendirici:
// her mekânın büyük katmanlarını (uzak/orta/zemin) her mevsim için yeniden render etmek doku
// belleğini ve paket boyutunu üçe katlardı; bunun yerine aynı doku renk aralığına göre yeniden
// boyanır. Sıra: maske A (yeşillik: iki varyant gürültüyle karışır), maske B (ikincil renk
// aralığı: kiremit, kum ...), genel doygunluk/ton/açma, son olarak silüet üstüne yumuşak kar.
// Gün tonu (self_modulate) EN SONDA çarpılır: önce mevsim, sonra günün ışığı.
// Maliyet: 1 doku okuması (+ kar açıksa 3), birkaç HSV dönüşümü; yaz bu malzemeyi hiç kullanmaz.

uniform vec4 a_mask = vec4(0.31, 0.13, 0.06, 0.0);   // ton merkezi, ton genişliği, en az doygunluk, miktar
uniform vec3 a_one = vec3(0.0, 1.0, 1.0);            // ton kayması, doygunluk çarpanı, parlaklık çarpanı
uniform vec3 a_two = vec3(0.0, 1.0, 1.0);
uniform vec2 a_split = vec2(0.5, 0.0);               // gürültü eşiği, varyant 2'nin parlaklığa bağlılığı
uniform vec4 a_mix = vec4(1.0, 1.0, 1.0, 0.0);       // hedef renk + miktar (kışın çim -> kar)
uniform vec4 b_mask = vec4(0.05, 0.07, 0.25, 0.0);
uniform vec3 b_one = vec3(0.0, 1.0, 1.0);
uniform vec4 b_mix = vec4(1.0, 1.0, 1.0, 0.0);
uniform float g_sat = 1.0;
uniform vec3 g_tint = vec3(1.0);
uniform vec4 g_lift = vec4(1.0, 1.0, 1.0, 0.0);
uniform float noise_scale = 0.012;
uniform float edge_snow = 0.0;
uniform float edge_px = 9.0;
uniform vec3 snow_color = vec3(0.957, 0.973, 1.0);

varying vec4 v_tint;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void vertex() {
	// Tepe rengi self_modulate + ebeveyn modulate'ini taşır (gün tonu, mekân geçişi saydamlığı).
	v_tint = COLOR;
}

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-5;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Yumuşak değer gürültüsü: lekeler hücre ölçeğinde, kenarsız (piksel/benek görünümü yok).
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float hue_mask(vec3 hsv, vec4 m) {
	float dh = abs(fract(hsv.x - m.x + 0.5) - 0.5);
	return (1.0 - smoothstep(m.y * 0.5, m.y, dh)) * smoothstep(m.z, m.z + 0.08, hsv.y) * m.w;
}

vec3 shifted(vec3 hsv, vec3 op) {
	return hsv2rgb(vec3(fract(hsv.x + op.x), clamp(hsv.y * op.y, 0.0, 1.0), clamp(hsv.z * op.z, 0.0, 1.0)));
}

// Hedef renge, yerel gölgeyi koruyarak çekilir: kar/kırağı düz beyaz leke gibi değil, kabartılı kalır.
vec3 toward(vec3 rgb, vec4 target) {
	float shade = clamp(0.55 + 0.55 * dot(rgb, LUMA), 0.0, 1.15);
	return mix(rgb, target.rgb * shade, target.a);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;
	vec3 hsv = rgb2hsv(rgb);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float n = smoothstep(0.25, 0.75, vnoise(px * noise_scale));
	float ma = hue_mask(hsv, a_mask);
	if (ma > 0.0) {
		float k = smoothstep(a_split.x - 0.1, a_split.x + 0.1, n);
		// İkinci varyant istenirse yalnız aydınlık (üstten ışık alan) yüzeylere düşer: tomurcuk/çiçek
		// lekeleri tombul kümelerin tepesinde durur, gölgeye yayılmaz.
		k *= mix(1.0, smoothstep(0.62, 0.86, hsv.z), a_split.y);
		vec3 graded = mix(shifted(hsv, a_one), shifted(hsv, a_two), k);
		rgb = mix(rgb, toward(graded, a_mix), ma);
	}
	float mb = hue_mask(hsv, b_mask);
	if (mb > 0.0) {
		rgb = mix(rgb, toward(shifted(hsv, b_one), b_mix), mb);
	}
	float luma = dot(rgb, LUMA);
	rgb = mix(vec3(luma), rgb, g_sat) * g_tint;
	rgb = mix(rgb, g_lift.rgb, g_lift.a);
	if (edge_snow > 0.0) {
		// Silüet üstü kar: bu piksel dolu, birkaç piksel yukarısı boşsa (çatı, tepe, çit ucu) beyaz.
		// Üç örnek yumuşak bir kalınlık geçişi verir; x boyunca gürültü kalınlığı dalgalandırır.
		float wobble = 0.75 + 0.5 * vnoise(vec2(px.x * 0.05, 3.0));
		float step_px = edge_px * wobble * TEXTURE_PIXEL_SIZE.y;
		float cap = 0.35 * (1.0 - texture(TEXTURE, UV - vec2(0.0, step_px * 0.35)).a)
			+ 0.35 * (1.0 - texture(TEXTURE, UV - vec2(0.0, step_px * 0.7)).a)
			+ 0.3 * (1.0 - texture(TEXTURE, UV - vec2(0.0, step_px)).a);
		rgb = mix(rgb, snow_color, clamp(cap, 0.0, 1.0) * edge_snow);
	}
	COLOR = vec4(rgb, tex.a) * v_tint;
}
