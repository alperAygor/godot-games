shader_type spatial;
// Neon zemin: ince + ana ızgara, oyuncu çevresinde parlama, dalga darbesi halkası.

uniform vec3 base_color : source_color = vec3(0.008, 0.013, 0.028);
uniform vec3 line_color : source_color = vec3(0.10, 0.45, 0.68);
uniform vec3 accent_color : source_color = vec3(0.8, 0.2, 1.0);
uniform float cell = 1.0;
uniform float glow = 0.28;
uniform float outer = 0.0;
uniform vec2 player_pos = vec2(0.0);
uniform float pulse = 0.0;
uniform vec2 pulse_origin = vec2(0.0);
uniform float danger = 0.0;

varying vec3 world_pos;

float grid(vec2 p, float width) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(0.0001));
	return 1.0 - min(min(g.x, g.y) / width, 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / cell;
	float fine = grid(p, 1.0);
	float major = grid(p / 4.0, 1.7);
	float line = max(fine * 0.5, major);
	float d_player = length(world_pos.xz - player_pos);
	float near = smoothstep(17.0, 2.0, d_player);
	float fade = mix(0.34 + 0.66 * near, smoothstep(80.0, 24.0, length(world_pos.xz)) * 0.55, outer);
	float flow = 0.5 + 0.5 * sin((world_pos.x + world_pos.z) * 0.32 - TIME * 1.3);
	float ring = 0.0;
	if (pulse > 0.001) {
		float pd = length(world_pos.xz - pulse_origin);
		ring = smoothstep(4.0, 0.0, abs(pd - pulse * 62.0)) * (1.0 - pulse);
	}
	vec3 lc = mix(line_color, accent_color, clamp(major * flow * 0.4 + danger * 0.55, 0.0, 1.0));
	float intensity = line * fade + ring * (0.25 + line * 1.6);
	ALBEDO = mix(base_color, lc, clamp(line * 0.55 * fade, 0.0, 1.0));
	METALLIC = 0.4;
	ROUGHNESS = 0.42;
	EMISSION = lc * intensity * glow + lc * near * 0.012 * (1.0 - outer) + accent_color * ring * 0.05;
}
