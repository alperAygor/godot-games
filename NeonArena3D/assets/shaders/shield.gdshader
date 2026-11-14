shader_type spatial;
// Kalkan balonu: kenar parlaması (fresnel) + akan çizgiler.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 color : source_color = vec3(0.4, 0.8, 1.0);
uniform float power = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	float lines = 0.5 + 0.5 * sin(UV.y * 70.0 + TIME * 4.0);
	ALBEDO = color * (1.3 + lines * 0.5);
	ALPHA = clamp((fres * 0.95 + 0.05 + lines * 0.04) * power, 0.0, 1.0);
}
