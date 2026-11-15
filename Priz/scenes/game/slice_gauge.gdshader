// Priz dikey kesit — sigorta kutusu hat göstergesi (assets/shaders/fuse_gauge.gdshader'ın oyun sürümü).
// Fark: blok boyu SABİT (göstergede `slots` yuva vardır; hat kapasitesi kadarı blok, üstü boş yuva).
// Böylece her hattın bloğu aynı boydadır ve tepsideki cihazın blok yığınıyla birebir karşılaştırılır.
// Rakam yok: yük = yanan blok sayısı.
//   fill      : yük / kapasite (0..1; >1 taşma)            — FuseBox sürer (yumuşak dolum)
//   segments  : hat kapasitesi (blok)                      — FuseBox sürer
//   highlight : dokunma vurgusu                            — FuseBox sürer
//   ghost     : sürüklenen cihazın ekleyeceği blok (blok cinsinden, nabız atar)
//   reject    : 0..1 ret parlaması (sığmayan bloklar kırmızı yanıp söner)
//   bounce    : 0..1 yeni dolan blokların sekme parlaması
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 warn_color : source_color = vec4(1.0, 0.62, 0.15, 1.0);
uniform vec4 over_color : source_color = vec4(1.0, 0.18, 0.12, 1.0);
uniform float energy = 1.6;
uniform float slots = 6.0;
instance uniform float fill : hint_range(0.0, 2.0) = 0.0;
instance uniform float segments = 6.0;
instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 tint : source_color = vec4(0.25, 0.85, 0.45, 1.0);
instance uniform float ghost = 0.0;
instance uniform float reject = 0.0;
instance uniform float bounce = 0.0;

void fragment() {
	float total = max(slots, 1.0);
	float cap = clamp(segments, 1.0, total);
	float y = UV.y * total;
	float idx = floor(y);
	float fy = fract(y);
	float gap = 0.16;
	float bx = smoothstep(0.0, 0.1, UV.x) * smoothstep(1.0, 0.9, UV.x);
	float by = smoothstep(gap * 0.5, gap * 0.5 + 0.07, fy) * smoothstep(1.0 - gap * 0.5, 1.0 - gap * 0.5 - 0.07, fy);
	float block = bx * by;
	float exists = step(idx + 0.5, cap);
	float level = fill * cap;
	float lit = clamp(level - idx, 0.0, 1.0) * exists;
	float ratio = fill;
	vec3 col = tint.rgb;
	col = mix(col, warn_color.rgb, smoothstep(0.8, 1.0, ratio) * step(cap - 1.5, idx));
	float over = step(1.0001, ratio);
	float flash = 0.55 + 0.45 * sin(TIME * 14.0);
	col = mix(col, over_color.rgb, over);
	// Hayalet bloklar: dolu bloğun üstünde, eklenecek kadar; sığmayanlar kırmızı.
	float g0 = floor(level + 0.5);
	float in_ghost = step(g0 - 0.5, idx) * step(idx + 0.5, g0 + ghost) * step(0.01, ghost);
	float ghost_fits = exists;
	float pulse = 0.5 + 0.5 * sin(TIME * 9.0);
	// Ret: boş (sığmayan yere denk gelen) bloklar kırmızı yanar.
	float rej = reject * (1.0 - lit) * exists;
	float e = lit * block * energy * mix(1.0, flash * 1.6, over) * (1.0 + bounce * 0.8);
	vec3 off_col = tint.rgb * 0.12 + vec3(0.03);
	vec3 slot_col = vec3(0.045, 0.04, 0.038);
	vec3 base = mix(slot_col, off_col, exists);
	vec3 alb = mix(base, col * 0.6, lit);
	vec3 ghost_col = mix(over_color.rgb, tint.rgb, ghost_fits);
	alb = mix(alb, ghost_col * 0.5, in_ghost * (1.0 - lit) * (0.35 + 0.4 * pulse));
	ALBEDO = mix(vec3(0.02), alb, block);
	ROUGHNESS = 0.18;
	SPECULAR = 0.7;
	vec3 em = col * e + tint.rgb * highlight * 0.7 * block * exists;
	em += ghost_col * in_ghost * (1.0 - lit) * block * (0.5 + 1.1 * pulse);
	em += over_color.rgb * rej * block * 2.2 * flash;
	EMISSION = em;
}
