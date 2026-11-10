shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Pano yüzeyindeki hafif devre şeması + teknik ızgara.
// BoardBuilder tarafından panonun 4 mm önüne yerleştirilen ince bir quad üzerinde.
// Amaç okunurluğu bozmadan "endüstriyel devre" dokusu vermek; alfa düşük tutulur.

uniform vec4 grid_color : source_color = vec4(0.18, 0.72, 0.64, 1.0);
uniform vec4 trace_color : source_color = vec4(0.95, 0.74, 0.28, 1.0);
uniform float grid_scale : hint_range(1.0, 64.0) = 22.0;
uniform float grid_intensity : hint_range(0.0, 1.0) = 0.16;
uniform float trace_intensity : hint_range(0.0, 1.0) = 0.38;
uniform float scan_speed : hint_range(0.0, 1.0) = 0.05;

float hairline(float value, float center, float width) {
	return 1.0 - smoothstep(0.0, width, abs(value - center));
}

void fragment() {
	vec2 uv = UV;

	// --- teknik ızgara: hücre kenarlarında ince parlak çizgi ---
	vec2 cell = uv * vec2(grid_scale, grid_scale * 1.75);
	vec2 grid_delta = abs(fract(cell) - 0.5) / max(fwidth(cell), vec2(0.0001));
	float grid = 1.0 - min(min(grid_delta.x, grid_delta.y), 1.0);

	// --- devre şeması: iki yatay hat + dikey jumper'lar ---
	float trace = 0.0;
	trace += hairline(uv.y, 0.22, 0.0022);
	trace += hairline(uv.y, 0.57, 0.0022);
	trace += hairline(uv.y, 0.81, 0.0018);
	trace += hairline(uv.x, 0.16, 0.0022) * step(0.22, uv.y) * step(uv.y, 0.57);
	trace += hairline(uv.x, 0.63, 0.0022) * step(0.57, uv.y) * step(uv.y, 0.81);
	trace += hairline(uv.x, 0.82, 0.0022) * step(0.22, uv.y) * step(uv.y, 0.57);

	// hat üzerinde yavaşça kayan enerji parıltısı
	float glow_x = fract(uv.x - TIME * scan_speed);
	float pulse = pow(max(sin(glow_x * 6.2831 * 3.0), 0.0), 14.0);
	trace += pulse * (hairline(uv.y, 0.22, 0.0045) + hairline(uv.y, 0.57, 0.0045)) * 0.8;

	// --- köşe işaretleri (kadraj hissi) ---
	float corner = step(0.985, max(abs(uv.x - 0.5) * 2.0, abs(uv.y - 0.5) * 2.0));

	// kenarlarda yumuşak sönüm: quad sınırı görünmesin
	float edge = smoothstep(0.0, 0.035, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));

	float alpha = (grid * grid_intensity + trace * trace_intensity + corner * 0.05) * edge;
	vec3 color = mix(grid_color.rgb, trace_color.rgb, clamp(trace * 1.6, 0.0, 1.0));

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
