// Priz — tüm priz hat işaretleri (renk + şekil) tek ağda. Köşe rengi:
//   COLOR.r = (priz sırası + 0.5) / 8   (Socket_01 → 0)
//   COLOR.g = (hat - 1 + 0.5) / 4
// RoomView dizi parametrelerini sürer: highlight[8] (vurgu), dim[8] (takılamaz → soluk).
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 line_colors[4] : source_color;
uniform float highlight[8];
uniform float dim[8];

varying flat int socket_id;
varying flat int line_id;

void vertex() {
	socket_id = clamp(int(COLOR.r * 8.0), 0, 7);
	line_id = clamp(int(COLOR.g * 4.0), 0, 3);
}

void fragment() {
	vec3 c = line_colors[line_id].rgb;
	float d = dim[socket_id];
	float h = highlight[socket_id];
	ALBEDO = mix(c, vec3(0.32), d);
	ROUGHNESS = 0.32;
	SPECULAR = 0.5;
	float pulse = 0.75 + 0.25 * sin(TIME * 6.0);
	EMISSION = c * h * 2.6 * pulse * (1.0 - d);
}
