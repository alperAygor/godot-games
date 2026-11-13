shader_type canvas_item;

#include "res://assets/shaders/color_pattern.gdshaderinc"

// Asılı kumaş sallanması. Neden fragment'ta UV kaydırma: Sprite2D yalnız 4 köşeli bir
// dörtgendir; köşe kaydırmayla bükülme olmaz. Bu yüzden dokuyu yatayda kaydırırız ve
// kaydırma taşmasın diye dörtgeni vertex() içinde yanlara genişletiriz (pad).

// Ip çizgisi dokuda bu v değerindedir (sprite tuvalinin ~%10'u); üstü sabit kalır.
uniform float pin_v = 0.10;
// Mandal bölgesinden sonra sallanma bu kadar uzunlukta yumuşakça açılır.
uniform float ramp_len = 0.45;
// Genlik (UV birimi) ve oyun tarafından fırtınada yükseltilen çarpan.
uniform float amplitude = 0.022;
uniform float strength = 1.0;
uniform float speed = 1.25;
uniform float waves = 3.2;
uniform float phase = 0.0;
// Komşu çamaşır alınınca / uçuşta gecikmeyle gelen anlık itme (işaretli, UV birimi).
uniform float kick = 0.0;
// Dörtgenin yanlara genişletilmesi (UV birimi).
uniform float pad = 0.16;
// Gölge için: renk yerine yalnız alfa siluetini boya.
uniform bool silhouette = false;

// Renk deseni (renk körü dostu): ColorPatterns doldurur. id < 1 = desen yok (düz/gizli/kapalı).
// Neden aynı materyalde: ek çizim çağrısı yok; desen sallanan UV'yi izler, kumaşta yüzer gibi durmaz.
uniform int pattern_id = -1;
// Çift renkli çamaşır: sağ yarı bu desenle (pattern_split açıkken); sol yarı pattern_id.
uniform int pattern_id_b = -1;
uniform bool pattern_split = false;
// Dokunun genişliğine düşen hücre sayısı (katlanmış parça daha az hücre ile bold kalır).
uniform float pattern_cells = 8.0;
// Kapalı/soluk çamaşırda desen daha silik.
uniform float pattern_strength = 1.0;
// 1 = desen açık tonlu (koyu kumaşta), 0 = koyu tonlu (açık kumaşta).
uniform float pattern_light = 0.0;
uniform float pattern_light_b = 0.0;

varying vec4 tint;
// Dokunun dünya boyunda yükseklik/genişlik oranı: çarşaf gibi gerilmiş sprite'ta hücreler kare kalır.
varying float pat_aspect;

void vertex() {
	tint = COLOR;
	float len_x = length(MODEL_MATRIX[0].xy) / TEXTURE_PIXEL_SIZE.x;
	float len_y = length(MODEL_MATRIX[1].xy) / TEXTURE_PIXEL_SIZE.y;
	pat_aspect = len_y / max(len_x, 1e-4);
	float side = UV.x < 0.5 ? -1.0 : 1.0;
	VERTEX.x += side * pad / TEXTURE_PIXEL_SIZE.x;
	UV.x += side * pad;
}

void fragment() {
	float weight = smoothstep(pin_v, pin_v + ramp_len, UV.y);
	weight = weight * weight;
	float t = TIME * speed + phase;
	float wave = sin(t + UV.y * waves) + 0.35 * sin(t * 1.9 + phase * 1.3 + UV.y * waves * 1.7);
	float shift = (wave * amplitude * strength + kick * amplitude * 8.0) * weight;
	vec2 uv = vec2(UV.x - shift, UV.y);
	// Genişletilen şerit dokunun dışında kalır: şeffaf bırak (kenar pikseli uzamasın).
	float inside = step(0.0, uv.x) * step(uv.x, 1.0);
	vec4 tex = texture(TEXTURE, uv);
	float alpha = tex.a * tint.a * inside;
	if (silhouette) {
		COLOR = vec4(tint.rgb, alpha);
	} else {
		vec3 rgb = tex.rgb * tint.rgb;
		if (pattern_id >= 1 || (pattern_split && pattern_id_b >= 1)) {
			vec2 p = vec2(uv.x, uv.y * pat_aspect) * pattern_cells;
			float mask = pattern_mask(pattern_id, p);
			float light = pattern_light;
			if (pattern_split) {
				// Orta çizgide yumuşak geçiş; iki yarı farklı desen + ton alabilir.
				float right = smoothstep(0.5 - fwidth(uv.x), 0.5 + fwidth(uv.x), uv.x);
				mask = mix(mask, pattern_mask(pattern_id_b, p), right);
				light = mix(pattern_light, pattern_light_b, right);
			}
			rgb = pattern_apply(rgb, mask, light, pattern_strength);
		}
		COLOR = vec4(rgb, alpha);
	}
}
