// Priz — tüm duvar hattı kabloları tek ağda (tek çizim çağrısı). Hat kimliği köşe renginde:
// COLOR.g = (hat - 1 + 0.5) / 4. Hat başına değerler dizi parametreleriyle (RoomView) verilir:
//   glow[i]      : 0 sönük, 1 akım, 2+ sınırda
//   highlight[i] : dokunma vurgusu
//   dim[i]       : sürüklemede solukluk
// UV.y kablo boyunca metre (akış dalgaları için).
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 line_colors[4] : source_color;
uniform vec4 jacket_color : source_color = vec4(0.85, 0.82, 0.78, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.78;
uniform float flow_speed = 0.35;
uniform float flow_scale = 7.0;
uniform float glow[4];
uniform float highlight[4];
uniform float dim[4];

varying flat int line_id;

void vertex() {
	line_id = clamp(int(COLOR.g * 4.0), 0, 3);
}

void fragment() {
	vec3 lc = line_colors[line_id].rgb;
	float d = dim[line_id];
	vec3 base = mix(jacket_color.rgb, lc, tint_amount);
	// Kılıfta ince sarmal sırt: yakın plandan PVC hissi.
	float ridge = 0.5 + 0.5 * sin((UV.x + UV.y * 4.0) * 6.2831 * 3.0);
	ALBEDO = base * (0.9 + 0.1 * ridge) * (1.0 - 0.55 * d);
	ROUGHNESS = 0.38 + 0.12 * (1.0 - ridge);
	SPECULAR = 0.45;
	float flow = 0.5 + 0.5 * sin(UV.y * flow_scale - TIME * flow_speed * 6.2831);
	flow = smoothstep(0.2, 1.0, flow);
	float e = glow[line_id] * (0.45 + 0.55 * flow) + highlight[line_id] * 1.6;
	EMISSION = lc * e * (1.0 - d);
}
