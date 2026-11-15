// Priz aşama 3 — gün kipi dilim göstergesi. TEK gölgelendirici üç yerde:
//  * sigorta kutusu (MultiMesh, hat başına bir örnek): dört tüp (sabah, öğle, akşam, gece) yan yana; tüp boyu =
//    hattın kapasitesi, yanan bloklar = o dilimdeki yük; taşan dilim sakin kırmızı nabız + kapağın üstünde blok.
//  * tepsideki cihaz rozeti (MeshInstance, örnek değişkenleri): aynı dört sütun, yalnız cihazın çalıştığı
//    dilimlerde cihazın blokları → sürüklerken göstergeye eklenen hayalet bloklarla birebir aynı biçim.
//  * odadaki cihaz şeridi (MultiMesh, rows = 0): yalnız dört dilim hücresi; çalıştığı dilimler renkli.
// Altta her sütunun dilim simgesi (güneş doğuşu, tepe güneş, gün batımı, ay) dilim renginde. RAKAM YOK.
//
// Örnek verisi (MultiMesh: INSTANCE_CUSTOM + COLOR; tekil: instance uniform):
//   loads  vec4 : dilim başına blok
//   p.x cap     : tüp boyu (kapasite; rozet için cihaz yükü)
//   p.y ghost   : sürüklenen cihazın ekleyeceği blok
//   p.z         : ghost_mask (4 bit) + 16 * tint_mode (0 hat rengi, 1 nötr, 2 kırmızı)
//   p.w flags   : line(2 bit) | (focus+1)<<2 | (fault+1)<<5 | highlight<<8 | dim<<9
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform bool from_multimesh = false;
// > 0: sabit satır sayısı (gösterge); 0: satır = cap (rozet); şerit için cap = 0.
uniform float rows = 0.0;
uniform float power = 1.0;          // şebeke (karartma)
uniform float reveal = 1.0;         // odak sütununun dolum animasyonu (0..1)
uniform vec4 line_color_1 : source_color = vec4(0.95, 0.40, 0.33, 1.0);
uniform vec4 line_color_2 : source_color = vec4(0.33, 0.62, 0.95, 1.0);
uniform vec4 line_color_3 : source_color = vec4(0.98, 0.78, 0.30, 1.0);
uniform vec4 line_color_4 : source_color = vec4(0.62, 0.45, 0.88, 1.0);
uniform vec4 neutral_color : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform vec4 bad_color : source_color = vec4(1.0, 0.22, 0.14, 1.0);
uniform vec4 warn_color : source_color = vec4(1.0, 0.62, 0.15, 1.0);
uniform vec4 slice_morning : source_color = vec4(0.55, 0.74, 0.95, 1.0);
uniform vec4 slice_noon : source_color = vec4(1.0, 0.84, 0.28, 1.0);
uniform vec4 slice_evening : source_color = vec4(1.0, 0.52, 0.22, 1.0);
uniform vec4 slice_night : source_color = vec4(0.36, 0.40, 0.86, 1.0);
uniform vec4 plate_color : source_color = vec4(0.055, 0.05, 0.05, 1.0);
uniform float energy = 1.7;
// Blok yüksekliği (birim; sütun genişliği = 1). Gösterge bandı dolsun diye DayGauges hesaplar.
uniform float block_h = 1.1;

instance uniform vec4 loads = vec4(0.0);
instance uniform vec4 params = vec4(0.0);

varying flat vec4 v_loads;
varying flat vec4 v_p;

// Birim ölçüler (GDScript DayGauges.unit_size ile AYNI tutulur).
const float COL_GAP = 0.28;
const float MARGIN = 0.32;
const float FOOT_H = 1.15;
const float FOOT_GAP = 0.18;
const float TOP_M = 0.3;
const float BOT_M = 0.28;

void vertex() {
	if (from_multimesh) {
		v_loads = INSTANCE_CUSTOM;
		v_p = COLOR;
	} else {
		v_loads = loads;
		v_p = params;
	}
}

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Dilim simgesi maskesi; q hücre merkezli, [-0.5, 0.5].
float slice_icon(int s, vec2 q, float aa) {
	if (s == 3) {
		// Ay: hilal + küçük yıldız
		float a = length(q - vec2(-0.03, 0.0)) - 0.27;
		float b = length(q - vec2(0.1, 0.09)) - 0.23;
		float moon = max(a, -b);
		float star = length(q - vec2(0.24, -0.2)) - 0.045;
		return 1.0 - smoothstep(-aa, aa, min(moon, star));
	}
	float horizon = -0.16;
	if (s == 1) {
		float d = length(q) - 0.17;
		float ang = atan(q.y, q.x);
		float ray = abs(fract(ang / 0.7853982 + 0.5) - 0.5) * 0.7853982 * length(q);
		float rays = max(ray - 0.035, max(0.25 - length(q), length(q) - 0.4));
		return 1.0 - smoothstep(-aa, aa, min(d, rays));
	}
	// Sabah (ışınlı doğan güneş) ve akşam (ışınsız batan büyük güneş): ufkun üstünde yarım disk + ufuk çizgisi.
	float r = (s == 0) ? 0.2 : 0.27;
	vec2 c = vec2(0.0, horizon);
	float disc = max(length(q - c) - r, horizon - q.y);
	float line = max(abs(q.y - horizon + 0.035) - 0.03, abs(q.x) - 0.4);
	float d = min(disc, line);
	if (s == 0) {
		vec2 qq = q - c;
		float ang = atan(qq.y, qq.x);
		float ray = abs(fract((ang - 0.3927) / 0.7853982 + 0.5) - 0.5) * 0.7853982 * length(qq);
		float rays = max(max(ray - 0.03, max(0.27 - length(qq), length(qq) - 0.4)), horizon + 0.02 - q.y);
		d = min(d, rays);
	}
	return 1.0 - smoothstep(-aa, aa, d);
}

vec3 slice_color(int s) {
	if (s == 0) return slice_morning.rgb;
	if (s == 1) return slice_noon.rgb;
	if (s == 2) return slice_evening.rgb;
	return slice_night.rgb;
}

vec3 line_color(int l) {
	if (l == 0) return line_color_1.rgb;
	if (l == 1) return line_color_2.rgb;
	if (l == 2) return line_color_3.rgb;
	return line_color_4.rgb;
}

void fragment() {
	float cap = v_p.x;
	float ghost = v_p.y;
	int gz = int(v_p.z + 0.5);
	int ghost_mask = gz & 15;
	int tint_mode = gz >> 4;
	int flags = int(v_p.w + 0.5);
	int line = flags & 3;
	int focus = ((flags >> 2) & 7) - 1;
	int fault = ((flags >> 5) & 7) - 1;
	float hl = float((flags >> 8) & 1);
	float dim = float((flags >> 9) & 1);
	float nrows = rows > 0.0 ? rows : cap;
	bool strip = nrows < 0.5;

	float W = 4.0 + 3.0 * COL_GAP + 2.0 * MARGIN;
	float BH = block_h;
	float H = TOP_M + nrows * BH + (strip ? 0.0 : FOOT_GAP) + FOOT_H + BOT_M;
	vec2 p = vec2(UV.x * W, (1.0 - UV.y) * H);
	float aa = fwidth(p.x) * 1.2;

	// Plaka: yuvarlak köşeli; dışı atılır.
	float plate = sd_box(p - vec2(W, H) * 0.5, vec2(W, H) * 0.5, 0.45);
	if (plate > 0.0) {
		discard;
	}
	vec3 tint = line_color(line);
	if (tint_mode == 1) tint = neutral_color.rgb;
	if (tint_mode == 2) tint = bad_color.rgb;
	float pulse = 0.5 + 0.5 * sin(TIME * 6.0);
	float calm = 0.5 + 0.5 * sin(TIME * 3.0);

	vec3 alb = plate_color.rgb * (1.0 + 0.6 * hl);
	vec3 em = vec3(0.0);
	// Sigorta "neden"i karanlıkta da parlar (şebekeden bağımsız).
	vec3 em_hot = vec3(0.0);
	// Plaka kenarında ince açık çerçeve (cam/krom hissi)
	float rim = 1.0 - smoothstep(0.0, 0.09, -plate);
	alb = mix(alb, vec3(0.32, 0.3, 0.28), rim * 0.8);
	em += tint * hl * rim * 0.8;

	float x = p.x - MARGIN;
	float cw = 1.0 + COL_GAP;
	int c = clamp(int(floor(x / cw)), 0, 3);
	float fx = x - float(c) * cw;
	float load = v_loads[c];
	bool active = load > 0.5;
	bool over = !strip && load > cap + 0.5 && cap > 0.0;
	bool is_focus = focus < 0 || focus == c;
	float col_k = is_focus ? 1.0 : 0.2;
	vec3 sc = slice_color(c);
	float by0 = BOT_M + FOOT_H + FOOT_GAP;
	// Sütunun tamamı (ayak + tüp): odak ve "neden" çerçevesi için.
	float col_top = strip ? BOT_M + FOOT_H : by0 + max(cap, max(load, 1.0)) * BH;
	float col_box = sd_box(vec2(fx - 0.5, p.y - (BOT_M + col_top) * 0.5), vec2(0.5 + COL_GAP * 0.38,
		(col_top - BOT_M) * 0.5 + 0.12), 0.24);
	float col_line = 1.0 - smoothstep(0.0, 0.08, abs(col_box + 0.04));
	if (focus == c && !strip) {
		em += sc * col_line * 1.6;
	}
	if (fault == c) {
		em_hot += bad_color.rgb * col_line * (1.6 + 2.2 * pulse);
		em_hot += bad_color.rgb * (1.0 - smoothstep(-0.05, 0.05, col_box)) * 0.12 * (0.6 + 0.4 * pulse);
	}
	if (fx >= 0.0 && fx <= 1.0) {
		// --- ayak: dilim simgesi ---
		float fy0 = BOT_M;
		if (p.y >= fy0 && p.y <= fy0 + FOOT_H) {
			float cell = sd_box(vec2(fx - 0.5, p.y - fy0 - FOOT_H * 0.5), vec2(0.5, FOOT_H * 0.5), 0.18);
			float in_cell = 1.0 - smoothstep(-aa, aa, cell);
			float icon = slice_icon(c, vec2(fx - 0.5, (p.y - fy0 - FOOT_H * 0.5) / FOOT_H * 1.0), aa / FOOT_H);
			bool lit_cell = rows > 0.0 || active;
			vec3 cell_alb = lit_cell ? sc * 0.45 : vec3(0.06);
			vec3 icon_col = lit_cell ? vec3(1.0, 0.98, 0.92) : sc * 0.4;
			alb = mix(alb, mix(cell_alb, icon_col, icon), in_cell);
			float e_cell = lit_cell ? (0.35 + 0.9 * icon) : 0.15 * icon;
			em += mix(sc, icon_col, icon) * e_cell * in_cell * col_k * (strip ? 1.6 : 1.0);
		}
		// --- tüp: bloklar ---
		if (!strip && p.y >= by0 && p.y <= by0 + nrows * BH) {
			float yy = (p.y - by0) / BH;
			float r = floor(yy);
			float fyy = yy - r;
			float blk = sd_box(vec2(fx - 0.5, (fyy - 0.5) * BH), vec2(0.42, BH * 0.5 - 0.09), 0.1);
			float in_blk = 1.0 - smoothstep(-aa, aa, blk);
			float blk_edge = 1.0 - smoothstep(0.0, 0.07, abs(blk + 0.03));
			bool exists = r < cap - 0.5;
			float shown = (focus == c) ? load * reveal : load;
			bool lit = r < shown - 0.5 && exists;
			bool spill = over && r >= cap - 0.5 && r < shown - 0.5;
			bool in_ghost = ((ghost_mask >> c) & 1) == 1 && ghost > 0.5 && r >= load - 0.5 && r < load + ghost - 0.5;
			bool ghost_over = in_ghost && r >= cap - 0.5;
			// Tüp gövdesi (kapasite kadar yuva): koyu cam; taşan tüpün kenarı sakin kırmızı nabız.
			float tube = sd_box(vec2(fx - 0.5, p.y - by0 - cap * BH * 0.5), vec2(0.5, cap * BH * 0.5), 0.14);
			float in_tube = 1.0 - smoothstep(-aa, aa, tube);
			float tube_rim = (1.0 - smoothstep(0.0, 0.07, abs(tube + 0.035))) * step(0.5, cap);
			alb = mix(alb, tint * 0.1 + vec3(0.025), in_tube);
			alb = mix(alb, vec3(0.55, 0.53, 0.5), tube_rim * 0.7);
			em += (over ? bad_color.rgb * (0.9 + 1.3 * calm) : sc * 0.25) * tube_rim * col_k;
			// Sınıra yakın (dolu) tüp: en üst blok aynı renkte ama parlak nabız (renk değişmez).
			bool near = !over && cap > 0.0 && load >= cap - 0.5 && r >= cap - 1.5;
			vec3 bc = tint;
			if (lit) {
				alb = mix(alb, bc * 0.55, in_blk);
				float glow = near ? (1.15 + 0.55 * calm) : 1.0;
				em += mix(bc, vec3(1.0), near ? 0.25 * calm : 0.0) * in_blk * energy * col_k * glow;
			} else if (exists) {
				alb = mix(alb, tint * 0.14 + vec3(0.03), in_blk);
			}
			if (spill) {
				alb = mix(alb, bad_color.rgb * 0.5, in_blk);
				em += bad_color.rgb * in_blk * energy * col_k * (0.85 + 0.6 * calm);
			}
			if (in_ghost && !lit) {
				// Hayalet: parlak kenarlı, yarı dolu, nabız atan blok (taşacaksa kırmızı).
				vec3 gc = ghost_over ? bad_color.rgb : mix(tint, vec3(1.0), 0.35);
				alb = mix(alb, gc * 0.35, in_blk * 0.7);
				em += gc * in_blk * (0.35 + 0.75 * pulse);
				em += gc * blk_edge * (1.4 + 1.2 * pulse);
			}
			if (fault == c && (spill || lit)) {
				em_hot += (spill ? bad_color.rgb : tint) * in_blk * 0.8;
			}
		}
	}
	float k = (1.0 - 0.85 * dim) * power;
	ALBEDO = alb * (0.4 + 0.6 * k);
	EMISSION = em * k + em_hot;
	ROUGHNESS = 0.28;
	SPECULAR = 0.55;
}
