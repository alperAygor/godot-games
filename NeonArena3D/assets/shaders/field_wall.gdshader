shader_type spatial;
// Arena sınırı güç alanı: oyuncu yaklaşınca belirginleşir.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.2, 0.8, 1.0);
uniform vec2 player_pos = vec2(0.0);
uniform float flash = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = 1.0 - UV.y;
	float near = smoothstep(9.0, 1.0, length(world_pos.xz - player_pos));
	float along = world_pos.x + world_pos.z;
	float bars = smoothstep(0.42, 0.5, abs(fract(along * 0.5) - 0.5));
	float scan = 0.5 + 0.5 * sin(world_pos.y * 9.0 - TIME * 3.0);
	float foot = pow(1.0 - h, 5.0);
	float body = (1.0 - h) * (0.25 + 0.5 * scan) + bars * (1.0 - h) * 0.6;
	float a = foot * 0.22 + (near * 0.55 + flash * 0.4) * body * 0.45;
	ALBEDO = color * 0.9;
	ALPHA = clamp(a, 0.0, 1.0) * smoothstep(0.0, 0.12, h + 0.12);
}
