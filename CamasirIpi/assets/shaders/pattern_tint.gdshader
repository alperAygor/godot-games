shader_type canvas_item;

#include "res://assets/shaders/color_pattern.gdshaderinc"

// Sepet astarı gibi düz boyanan sprite'lara renk deseni: doku x modulate (Godot COLOR'a zaten
// çarpar), üstüne ton-üstü-ton desen. Sallanma yok -> sade ve ucuz.
uniform int pattern_id = -1;
uniform float pattern_cells = 14.0;
uniform float pattern_strength = 1.0;
uniform float pattern_light = 0.0;

void fragment() {
	if (pattern_id >= 1) {
		vec2 p = UV * pattern_cells;
		COLOR.rgb = pattern_apply(COLOR.rgb, pattern_mask(pattern_id, p), pattern_light, pattern_strength);
	}
}
