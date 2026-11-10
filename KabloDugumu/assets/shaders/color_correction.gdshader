shader_type canvas_item;
render_mode unshaded;

// Sıcak/soğuk dengeli tam ekran renk düzeltmesi — tek geçiş.
//
// Neden Environment adjustment_color_correction LUT'u değil: Godot 4.7
// gl_compatibility'de LUT bozuk sonuç veriyor (kimlik LUT bile sahneyi
// kırmızıya çeviriyor — GOTCHAS #3, ölçüldü). Bu shader aynı işi yapar.
// UI bu katmanın ÜSTÜNDE (HUD CanvasLayer 10, bu katman 1) kalır.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

// Gölgelere soğuk-neon birikmesi, highlight'larda amber sıcaklığı
uniform vec3 lift = vec3(0.012, 0.020, 0.030);
uniform vec3 gain = vec3(1.035, 1.005, 0.965);
uniform float exposure : hint_range(0.2, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 2.0) = 1.08;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.34;
uniform float vignette_start : hint_range(0.0, 1.0) = 0.52;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * exposure;

	// lift / gain: koyu tonlara teal, aydınlıklara hafif amber
	c = c * gain + lift * (1.0 - c);

	// doygunluk (neonları canlandırır)
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(luma), c, saturation);

	// kontrast (0.5 pivot)
	c = (c - vec3(0.5)) * contrast + vec3(0.5);

	// vinyet: bakışı panonun merkezine çeker, kenarları söndürür
	float dist = length(SCREEN_UV - vec2(0.5));
	float v = smoothstep(0.9, vignette_start, dist);
	c *= mix(1.0, v, vignette_strength);

	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
