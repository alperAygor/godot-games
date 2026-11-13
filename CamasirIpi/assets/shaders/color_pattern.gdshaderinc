// Renk deseni kütüphanesi (cloth_sway + pattern_tint ortak). Her renk kendi desenine sahiptir ki
// renk körü oyuncu renkleri tondan bağımsız ayırabilsin. Desenler ton-üstü-ton: kumaşın
// kendi gölgesiyle çarpılır, bu yüzden baskı gibi görünür; kenarlar fwidth ile yumuşatılır.
//
// Desen numaraları ColorPatterns (GDScript) ile birebir aynıdır:
// 0 düz (desen yok), 1 dikey çizgi, 2 puan, 3 kare (damalı), 4 çapraz çizgi, 5 zikzak, 6 artı.

const float PAT_LIGHTEN = 0.30;  // açık ton: beyaza doğru karışım
const float PAT_DARKEN = 0.26;   // koyu ton: çarpan kaybı
// Hücre çok küçülünce (uzak/küçük parça) desen tırtıklanır: bu eşikten sonra sönümlenir.
const float PAT_FADE_FROM = 0.28;
const float PAT_FADE_TO = 0.62;

// Üçgen dalga (periyot 1, 0..1): fract süreksizliği olmadan, fwidth ile güvenle yumuşatılır.
float pat_tri(float x) {
	return abs(fract(x * 0.5) * 2.0 - 1.0);
}

// d < r içinde 1, dışında 0; kenar w kadar yumuşak.
float pat_inside(float d, float r, float w) {
	float ww = max(w, 1e-4);
	return 1.0 - smoothstep(r - ww, r + ww, d);
}

// p: hücre birimi koordinat. Dönüş 0..1 maske.
float pattern_mask(int id, vec2 p) {
	vec2 fw = fwidth(p);
	float w = max(fw.x, fw.y);
	float m = 0.0;
	if (id == 1) {
		// Dikey çizgi: hücrenin %45'i dolu.
		float d = abs(fract(p.x) - 0.5);
		m = pat_inside(d, 0.22, w);
	} else if (id == 2) {
		// Puan: yarım kaymalı sıra, iri noktalar.
		vec2 q = p * vec2(1.0, 1.0);
		q.x += 0.5 * mod(floor(q.y), 2.0);
		float d = length(fract(q) - 0.5);
		m = pat_inside(d, 0.25, w);
	} else if (id == 3) {
		// Kare: iki yönlü kare dalganın XOR'u (damalı). Hücre 1/2 -> kare başına 1 birim.
		vec2 t = vec2(pat_tri(p.x), pat_tri(p.y));
		float sx = smoothstep(0.5 - w, 0.5 + w, t.x);
		float sy = smoothstep(0.5 - w, 0.5 + w, t.y);
		m = abs(sx - sy);
	} else if (id == 4) {
		// Çapraz çizgi: 45 derece, dikey çizgiden belirgin biçimde farklı.
		float u = (p.x + p.y) * 0.7071;
		float d = abs(fract(u) - 0.5);
		m = pat_inside(d, 0.2, w * 0.7071);
	} else if (id == 5) {
		// Zikzak: dalgalı şeritler (chevron).
		float v = p.y + (pat_tri(p.x) - 0.5) * 0.9;
		float d = abs(fract(v) - 0.5);
		m = pat_inside(d, 0.17, w * 1.3);
	} else if (id == 6) {
		// Artı: yarım kaymalı sıra, kalın kollu.
		vec2 q = p;
		q.x += 0.5 * mod(floor(q.y), 2.0);
		vec2 f = abs(fract(q) - 0.5);
		float bar_a = pat_inside(f.y, 0.1, w) * pat_inside(f.x, 0.3, w);
		float bar_b = pat_inside(f.x, 0.1, w) * pat_inside(f.y, 0.3, w);
		m = max(bar_a, bar_b);
	}
	// Uzak/küçük çizimde desen sessizce söner (moire yerine düz renk).
	return m * (1.0 - smoothstep(PAT_FADE_FROM, PAT_FADE_TO, w));
}

// col üstüne maske uygular: light=1 açık ton, 0 koyu ton. Çarpımsal olduğu için kumaş gölgesi korunur.
vec3 pattern_apply(vec3 col, float mask, float light, float amount) {
	float k = clamp(mask * amount, 0.0, 1.0);
	vec3 lit = mix(col, vec3(1.0), PAT_LIGHTEN * k);
	vec3 dark = col * (1.0 - PAT_DARKEN * k);
	return mix(dark, lit, light);
}
