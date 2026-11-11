shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.08, 0.06, 0.13, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.32;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.08;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;
uniform float falloff_power : hint_range(0.5, 4.0) = 1.5;

void fragment() {
	// Standard 0..1 plane UVs make this a texture-free contact decal.
	float radius = length((UV - vec2(0.5)) * 2.0);
	float coverage = 1.0 - smoothstep(inner_radius, outer_radius, radius);
	ALBEDO = base_color.rgb * shadow_color.rgb;
	ALPHA = pow(coverage, falloff_power) * opacity * base_color.a * shadow_color.a;
}
