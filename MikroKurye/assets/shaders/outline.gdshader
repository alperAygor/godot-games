shader_type spatial;
// Stil A ters-kabuk anahat. Kaynak: assets/shaders/style_lab/outline.gdshader.
// `next_pass` olarak toon malzemesinin ardına bağlanır; opak kaldığı için
// transparan sıralamaya düşmez (GOTCHAS: alpha yazılmaz).
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

uniform float width : hint_range(0.0, 0.1, 0.001) = 0.005;
uniform vec4 ink_color : source_color = vec4(0.125, 0.157, 0.243, 1.0);

void vertex() {
	// Mesh yerel uzayında genişleme: ekran boyutu/okuma ve viewport'tan bağımsızdır.
	// Genişlik bilinçli düşük tutulur: projenin GLB'leri ve BoxMesh'leri ayrık/düz
	// normal taşır (her paylaşılan köşede birden çok normal). Geniş hull bu köşelerde
	// yüz ayrışması (kesik/merdivenli çizgi) üretir; 0.005 ince parçaları (visor
	// 0.025 m, sepet rayı 0.06 m) yutmayacak kadar küçük, dikişleri görünür kılmayacak
	// kadar dardır. Kalıcı çözüm düzgün outline-normal (ikinci UV/mesh) gerektirir.
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
