shader_type spatial;
// Mermi: parlak çekirdek + renkli kenar, aydınlatmasız (glow'a girer).
render_mode unshaded, shadows_disabled;

uniform float energy = 2.6;

void fragment() {
	float core = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	ALBEDO = mix(COLOR.rgb, vec3(1.0), core * 0.8) * energy;
}
