// Priz — sigorta kutusu hat göstergesi: camın arkasında dikey blok dizisi.
// Rakam yok: yük = yanan blok sayısı. UV.y 0 alt, 1 üst; UV.x 0..1 genişlik.
//   fill      : yük / kapasite (0..1; >1 taşma)
//   segments  : blok sayısı (= hat kapasitesi)
//   highlight : dokunma vurgusu
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 line_color : source_color = vec4(0.25, 0.85, 0.45, 1.0);
uniform vec4 warn_color : source_color = vec4(1.0, 0.62, 0.15, 1.0);
uniform vec4 over_color : source_color = vec4(1.0, 0.18, 0.12, 1.0);
uniform float energy = 1.5;
instance uniform float fill : hint_range(0.0, 1.5) = 0.0;
instance uniform float segments = 6.0;
instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 tint : source_color = vec4(0.25, 0.85, 0.45, 1.0);

void fragment() {
	float segs = max(segments, 1.0);
	float y = UV.y * segs;
	float idx = floor(y);
	float fy = fract(y);
	float gap = 0.14;
	float bx = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	float by = smoothstep(gap * 0.5, gap * 0.5 + 0.06, fy) * smoothstep(1.0 - gap * 0.5, 1.0 - gap * 0.5 - 0.06, fy);
	float block = bx * by;
	float level = fill * segs;
	// Kısmi blok yumuşak dolar (animasyon için).
	float lit = clamp(level - idx, 0.0, 1.0);
	float ratio = fill;
	vec3 col = tint.rgb;
	col = mix(col, warn_color.rgb, smoothstep(0.8, 1.0, ratio) * step(segs - 1.5, idx));
	float over = step(1.0001, ratio);
	float flash = 0.55 + 0.45 * sin(TIME * 14.0);
	col = mix(col, over_color.rgb, over);
	float e = lit * block * energy * mix(1.0, flash * 1.6, over);
	// Sönük blok: koyu renkli cam; yanan: parlak.
	vec3 off_col = tint.rgb * 0.12 + vec3(0.03);
	ALBEDO = mix(vec3(0.02), mix(off_col, col * 0.6, lit), block);
	ROUGHNESS = 0.18;
	SPECULAR = 0.7;
	EMISSION = col * e + tint.rgb * highlight * 0.6 * block;
}
