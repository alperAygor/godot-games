shader_type canvas_item;
// Piksel görünümü: ekranı büyük bloklara ayırır (tasarım pikseli cinsinden `block`), renkleri azaltır (posterize),
// blokların üstüne çok hafif sıralı (Bayer) titreşim ve tarama çizgisi koyar. Ayarlar'dan kapatılabilir.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float block = 2.0;
uniform float levels = 28.0;
uniform float scanline = 0.07;
uniform float dither = 0.025;

const mat4 BAYER = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0));

void fragment() {
	vec2 size = vec2(textureSize(screen_tex, 0));
	float cell = max(1.0, block * size.x / 720.0);
	vec2 cell_index = floor(SCREEN_UV * size / cell);
	vec2 uv = (cell_index + 0.5) * cell / size;
	vec3 color = texture(screen_tex, uv).rgb;
	int bx = int(mod(cell_index.x, 4.0));
	int by = int(mod(cell_index.y, 4.0));
	float threshold = BAYER[bx][by] / 16.0 - 0.5;
	color += threshold * dither;
	color = floor(color * levels + 0.5) / levels;
	float row = mod(cell_index.y, 2.0);
	color *= 1.0 - scanline * row;
	COLOR = vec4(color, 1.0);
}
