shader_type spatial;
// Zemin halkası / yumuşak ışık diski. INSTANCE_CUSTOM: x=boş, y=kalınlık, z=mod (0 halka, 1 disk), w=iç dolgu.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float energy = 1.6;
varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = 0.0;
	if (custom.z < 0.5) {
		float th = clamp(custom.y, 0.02, 0.9);
		float outer_edge = 1.0 - smoothstep(0.93, 1.0, d);
		float inner_edge = smoothstep(1.0 - th - 0.07, 1.0 - th, d);
		a = outer_edge * inner_edge;
		a += outer_edge * custom.w * (0.08 + 0.1 * d);
	} else {
		a = pow(max(1.0 - d, 0.0), 1.7);
	}
	ALBEDO = COLOR.rgb * energy;
	ALPHA = clamp(a * COLOR.a, 0.0, 1.0);
}
