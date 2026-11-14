shader_type canvas_item;
// Kenar kararması + ince tarama çizgisi + hasar / düşük can kızarması.

uniform vec4 vignette_color : source_color = vec4(0.015, 0.01, 0.05, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float scanline_strength : hint_range(0.0, 0.4) = 0.035;
uniform vec2 resolution = vec2(1280.0, 720.0);
uniform vec3 hurt_color : source_color = vec3(1.0, 0.08, 0.22);
uniform float hurt = 0.0;
uniform float low_hp = 0.0;
uniform vec3 tint_color : source_color = vec3(0.3, 0.9, 1.0);
uniform float tint = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.12, 1.0)) * 1.45;
	float v = smoothstep(0.42, 1.06, d);
	float edge = smoothstep(0.2, 0.95, d);
	float scan = sin(UV.y * resolution.y * 1.6) * 0.5 + 0.5;
	float pulse = low_hp * (0.55 + 0.45 * sin(TIME * 5.2));
	float red = clamp(edge * (hurt * 0.95 + pulse * 0.6), 0.0, 1.0);
	float glow = clamp(edge * tint, 0.0, 1.0);
	vec3 col = mix(vignette_color.rgb, hurt_color, red);
	col = mix(col, tint_color, glow);
	float alpha = v * strength + scan * scanline_strength * (1.0 - v) + red * 0.5 + glow * 0.35;
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
