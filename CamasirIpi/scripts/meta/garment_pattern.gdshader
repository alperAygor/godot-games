// Koleksiyon kıyafetleri: nötr beyaz çamaşır sprite'ı (assets/sprites/garment_*.png) üstüne
// ülke temalı desen. Sprite'ın gri tonu kumaş gölgesidir; desen rengi onunla çarpılır, böylece
// kıvrımlar/dikişler desenin üstünde de okunur (oyundaki renk çarpımıyla aynı yaklaşım).
// Tüm kenarlar fwidth ile yumuşatılır: küçük boyutta da tırtık/piksel görünmez.
// silhouette=1: eksik parça -> yumuşak, yarı saydam gölge.
shader_type canvas_item;

uniform int pattern = 0; // 0 düz, 1 çizgi, 2 puan, 3 kare, 4 ekose, 5 dalga, 6 serape, 7 baklava, 8 çiçek, 9 zikzak
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(0.9, 0.3, 0.3, 1.0);
uniform vec4 color_c : source_color = vec4(0.3, 0.6, 0.9, 1.0);
uniform float scale = 6.0;
uniform float angle = 0.0; // derece
uniform float silhouette = 0.0;
uniform vec4 silhouette_color : source_color = vec4(0.25, 0.3, 0.28, 0.13);
// Gölge sprite'ları çok koyu tonları biraz kaldırır: desen renkleri çamurlaşmasın.
uniform float shade_lift = 0.12;

float edge(float threshold, float x) {
	float w = max(fwidth(x), 1e-4);
	return smoothstep(threshold - w, threshold + w, x);
}

// 0..1 aralığında bant: [lo, hi] içinde 1.
float band(float lo, float hi, float x) {
	return edge(lo, x) - edge(hi, x);
}

vec3 cycle3(float i) {
	float k = mod(i, 3.0);
	return k < 0.5 ? color_a.rgb : (k < 1.5 ? color_b.rgb : color_c.rgb);
}

// Eşit genişlikte çok renkli bantlar; komşu bant geçişi yumuşatılır.
vec3 bands3(float x) {
	float i = floor(x);
	float f = fract(x);
	float w = max(fwidth(x), 1e-4);
	float t = smoothstep(1.0 - w, 1.0, f);
	return mix(cycle3(i), cycle3(i + 1.0), t);
}

vec3 stripes(vec2 p) {
	float t = fract(p.x);
	vec3 base = mix(color_a.rgb, color_b.rgb, band(0.0, 0.5, t));
	float accent = 1.0 - edge(0.045, abs(t - 0.75));
	return mix(base, color_c.rgb, accent);
}

vec3 dots(vec2 p) {
	vec2 q = p;
	q.x += 0.5 * mod(floor(q.y), 2.0);
	float d = length(fract(q) - 0.5);
	return mix(color_a.rgb, color_b.rgb, 1.0 - edge(0.2, d));
}

vec3 checks(vec2 p) {
	float sx = edge(0.5, fract(p.x));
	float sy = edge(0.5, fract(p.y));
	return mix(color_a.rgb, color_b.rgb, abs(sx - sy));
}

vec3 tartan(vec2 p) {
	float bx = band(0.3, 0.7, fract(p.x));
	float by = band(0.3, 0.7, fract(p.y));
	vec3 col = color_a.rgb;
	col = mix(col, color_b.rgb, bx * 0.55);
	col = mix(col, color_b.rgb, by * 0.55);
	float lx = 1.0 - edge(0.03, abs(fract(p.x) - 0.08));
	float ly = 1.0 - edge(0.03, abs(fract(p.y) - 0.08));
	return mix(col, color_c.rgb, max(lx, ly) * 0.85);
}

// Seigaiha (Japon dalgası): üst üste binen yarım daireler, her biri eşmerkezli halkalı.
vec3 waves(vec2 p) {
	float best_row = -1e4;
	float best_d = 1.0;
	float base_row = floor(p.y * 2.0);
	for (int k = -1; k <= 2; k++) {
		float row = base_row + float(k);
		float xoff = mod(row, 2.0) * 0.5;
		for (int m = -1; m <= 1; m++) {
			vec2 c = vec2(floor(p.x - xoff) + 0.5 + xoff + float(m), row * 0.5);
			float d = distance(p, c);
			if (d < 0.5 && row > best_row) {
				best_row = row;
				best_d = d;
			}
		}
	}
	float rings = fract(best_d * 7.0);
	return mix(color_b.rgb, color_a.rgb, band(0.25, 0.75, rings));
}

vec3 serape(vec2 p) {
	vec3 col = bands3(p.x);
	// İnce beyazımsı ara şeritler: Meksika battaniyesinin canlı ritmi.
	float thin = 1.0 - edge(0.05, abs(fract(p.x * 2.0) - 0.5));
	return mix(col, vec3(1.0, 0.97, 0.9), thin * 0.75);
}

vec3 diamonds(vec2 p) {
	vec2 q = abs(fract(p + 0.5) - 0.5);
	float d = q.x + q.y;
	vec3 col = mix(color_a.rgb, color_b.rgb, 1.0 - edge(0.36, d));
	return mix(col, color_c.rgb, 1.0 - edge(0.13, d));
}

vec3 floral(vec2 p) {
	vec2 q = p;
	q.x += 0.5 * mod(floor(q.y), 2.0);
	vec2 f = fract(q) - 0.5;
	float r = length(f);
	float th = atan(f.y, f.x);
	float petal = 0.27 * (0.55 + 0.45 * abs(cos(2.5 * th)));
	vec3 col = mix(color_a.rgb, color_b.rgb, 1.0 - edge(petal, r));
	return mix(col, color_c.rgb, 1.0 - edge(0.075, r));
}

vec3 zigzag(vec2 p) {
	float y = p.y + abs(fract(p.x) - 0.5) * 1.2;
	return bands3(y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (silhouette > 0.5) {
		COLOR = vec4(silhouette_color.rgb, tex.a * silhouette_color.a);
	} else {
		float a = radians(angle);
		vec2 p = UV - 0.5;
		p = vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a)) * scale;
		vec3 col = color_a.rgb;
		if (pattern == 1) { col = stripes(p); }
		else if (pattern == 2) { col = dots(p); }
		else if (pattern == 3) { col = checks(p); }
		else if (pattern == 4) { col = tartan(p); }
		else if (pattern == 5) { col = waves(p); }
		else if (pattern == 6) { col = serape(p); }
		else if (pattern == 7) { col = diamonds(p); }
		else if (pattern == 8) { col = floral(p); }
		else if (pattern == 9) { col = zigzag(p); }
		vec3 shade = mix(tex.rgb, vec3(1.0), shade_lift);
		COLOR = vec4(col * shade, tex.a) * COLOR;
	}
}
