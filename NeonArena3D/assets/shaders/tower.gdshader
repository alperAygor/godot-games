shader_type spatial;
// Ufuk çizgisi blokları: yordamsal ışıklı pencereler (MultiMesh, INSTANCE_CUSTOM.x = tohum).
render_mode shadows_disabled;

uniform vec3 body : source_color = vec3(0.03, 0.05, 0.09);
uniform vec3 lit_a : source_color = vec3(0.1, 0.6, 0.85);
uniform vec3 lit_b : source_color = vec3(0.9, 0.25, 0.6);

varying vec3 local_pos;
varying vec3 local_normal;
varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_pos = VERTEX * sc;
	local_normal = NORMAL;
	seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	float side = step(abs(local_normal.y), 0.5);
	float u = abs(local_normal.x) > 0.5 ? local_pos.z : local_pos.x;
	vec2 uv = vec2(u * 1.7 + seed * 3.0, local_pos.y * 1.35);
	vec2 id = floor(uv);
	vec2 f = fract(uv);
	float window = step(0.22, f.x) * step(f.x, 0.78) * step(0.28, f.y) * step(f.y, 0.72);
	float r = hash(id + vec2(seed * 17.0, seed * 5.0));
	float on = step(0.6, r);
	float flicker = 0.78 + 0.22 * sin(TIME * (0.4 + r * 1.8) + r * 40.0);
	vec3 lit = mix(lit_a, lit_b, step(0.87, r));
	float roof = step(0.5, local_normal.y);
	ALBEDO = body;
	ROUGHNESS = 0.75;
	EMISSION = lit * window * on * side * flicker * 1.5 + lit_a * roof * 0.35;
}
