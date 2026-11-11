shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

uniform float width : hint_range(0.0, 0.1, 0.001) = 0.018;
uniform vec4 ink_color : source_color = vec4(0.055, 0.065, 0.10, 1.0);

void vertex() {
	// Mesh-local expansion keeps this independent of viewport and screen reads.
	VERTEX += NORMAL * width;
}

void fragment() {
	// Keep the hull opaque: writing ALPHA would move it to transparent sorting.
	ALBEDO = ink_color.rgb;
}
