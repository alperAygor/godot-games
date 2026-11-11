shader_type spatial;
// Sahte pencere ışığı hüzmesi: unshaded + additif, derinlik yazmaz.
// Hacimsel ışık/gerçek gölge maliyeti olmadan sıcak pencere hissi verir;
// yukarıdan aşağıya ve yanlara doğru sönümlenen yarı saydam plakadır.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.87, 0.64, 1.0);
uniform float edge_fade : hint_range(0.0, 1.0) = 0.45;
uniform float top_brightness : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	// Plakanın ortası parlak, iki yan kenarı yumuşakça sönük.
	float side = 1.0 - smoothstep(0.0, edge_fade, abs(UV.x - 0.5) * 2.0);
	// Pencere üstü parlak, zemine yaklaştıkça kaybolur (QuadMesh FACE_Z'de UV.y=1 üst kenardır).
	float falloff = pow(clamp(UV.y, 0.0, 1.0), 1.6);
	ALBEDO = beam_color.rgb;
	ALPHA = beam_color.a * side * falloff * top_brightness;
}
