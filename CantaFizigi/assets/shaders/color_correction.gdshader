shader_type canvas_item;
render_mode unshaded;

// Sıcak renk düzeltme (color correction) — tek tam ekran geçişi.
//
// Neden Environment'ın adjustment_color_correction LUT'u değil: Godot 4.7
// gl_compatibility'de 512x512 LUT bozuk sonuç veriyor (kimlik LUT bile sahneyi
// kırmızıya çeviriyor — ölçüldü). Bu shader aynı işi taşınabilir biçimde yapar.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

// lift / gain: gölgelere sıcak kaldırma, highlight'larda maviyi geri çekme
uniform vec3 lift = vec3(0.028, 0.014, 0.004);
uniform vec3 gain = vec3(1.045, 1.005, 0.955);
uniform float exposure : hint_range(0.2, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.14;
uniform float contrast : hint_range(0.5, 2.0) = 1.07;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.28;
uniform float vignette_start : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * exposure;

	// lift/gain (sıcak ton)
	c = c * gain + lift * (1.0 - c);

	// doygunluk
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(luma), c, saturation);

	// kontrast (0.5 pivot)
	c = (c - vec3(0.5)) * contrast + vec3(0.5);

	// vinyet — kenarları yumuşakça koyulaştırır, bakışı çantaya çeker
	vec2 d = (SCREEN_UV - vec2(0.5)) * vec2(1.0, 1.0);
	float v = smoothstep(0.9, vignette_start, length(d));
	c *= mix(1.0, v, vignette_strength);

	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
