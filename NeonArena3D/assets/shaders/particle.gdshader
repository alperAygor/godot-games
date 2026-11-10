shader_type spatial;
// Kıvılcım ve ışın: MultiMesh örnek rengiyle eklemeli parlama.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float energy = 2.4;

void fragment() {
	ALBEDO = COLOR.rgb * energy;
	ALPHA = COLOR.a;
}
