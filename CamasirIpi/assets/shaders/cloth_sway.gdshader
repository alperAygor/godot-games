shader_type canvas_item;

// Asılı kumaş sallanması. Neden fragment'ta UV kaydırma: Sprite2D yalnız 4 köşeli bir
// dörtgendir; köşe kaydırmayla bükülme olmaz. Bu yüzden dokuyu yatayda kaydırırız ve
// kaydırma taşmasın diye dörtgeni vertex() içinde yanlara genişletiriz (pad).

// Ip çizgisi dokuda bu v değerindedir (sprite tuvalinin ~%10'u); üstü sabit kalır.
uniform float pin_v = 0.10;
// Mandal bölgesinden sonra sallanma bu kadar uzunlukta yumuşakça açılır.
uniform float ramp_len = 0.45;
// Genlik (UV birimi) ve oyun tarafından fırtınada yükseltilen çarpan.
uniform float amplitude = 0.022;
uniform float strength = 1.0;
uniform float speed = 1.25;
uniform float waves = 3.2;
uniform float phase = 0.0;
// Komşu çamaşır alınınca / uçuşta gecikmeyle gelen anlık itme (işaretli, UV birimi).
uniform float kick = 0.0;
// Dörtgenin yanlara genişletilmesi (UV birimi).
uniform float pad = 0.16;
// Gölge için: renk yerine yalnız alfa siluetini boya.
uniform bool silhouette = false;

varying vec4 tint;

void vertex() {
	tint = COLOR;
	float side = UV.x < 0.5 ? -1.0 : 1.0;
	VERTEX.x += side * pad / TEXTURE_PIXEL_SIZE.x;
	UV.x += side * pad;
}

void fragment() {
	float weight = smoothstep(pin_v, pin_v + ramp_len, UV.y);
	weight = weight * weight;
	float t = TIME * speed + phase;
	float wave = sin(t + UV.y * waves) + 0.35 * sin(t * 1.9 + phase * 1.3 + UV.y * waves * 1.7);
	float shift = (wave * amplitude * strength + kick * amplitude * 8.0) * weight;
	vec2 uv = vec2(UV.x - shift, UV.y);
	// Genişletilen şerit dokunun dışında kalır: şeffaf bırak (kenar pikseli uzamasın).
	float inside = step(0.0, uv.x) * step(uv.x, 1.0);
	vec4 tex = texture(TEXTURE, uv);
	float alpha = tex.a * tint.a * inside;
	if (silhouette) {
		COLOR = vec4(tint.rgb, alpha);
	} else {
		COLOR = vec4(tex.rgb * tint.rgb, alpha);
	}
}
