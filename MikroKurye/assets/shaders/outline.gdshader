shader_type spatial;
// Stil A ters-kabuk anahat (yumuşatılmış). Kaynak: assets/shaders/style_lab/outline.gdshader.
// `next_pass` olarak toon malzemesinin ardına bağlanır; opak kaldığı için
// transparan sıralamaya düşmez (GOTCHAS: alpha yazılmaz).
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

// Genişlik `reference_distance` mesafesinde dünya birimi cinsinden ofsettir;
// daha yakın/uzakta derinlikle ölçeklenir. Böylece anahat ekranda yaklaşık sabit
// piksel kalınlığında kalır (kamera uzaklaştıkça incelmez/kalınlaşmaz).
uniform float width : hint_range(0.0, 0.1, 0.001) = 0.008;
uniform float reference_distance : hint_range(0.5, 50.0) = 6.0;
// Koyu lacivert (#20263A); saf siyah değil. Stil A silüetinin sıcak palete karışması
// için maviye kaydırılır.
uniform vec4 ink_color : source_color = vec4(0.125, 0.149, 0.227, 1.0);
// Düz/ayrık normalli (flat-shaded) mesh'lerde köşe ve dikişlerde kabuk yüz ayrışır
// (kesik/merdivenli anahat). Geometrik normali nesne-merkezli radyal yöne doğru
// karıştırmak, paylaşılan köşedeki çoklu yüz normalini tek yönde birleştirip dikişi
// kapatır. 0 = saf normal, 1 = saf radyal. 0.5 ince/uzun nesnelerde (kalem) kalınlığı
// korurken kompakt nesnelerde (gövde/tekerlek) dikişi büyük ölçüde kapatır.
uniform float normal_smooth : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	// Görüş uzayı derinliği; VERTEX_VIEW vertex()'te yok, model→görüş dönüşümü elle
	// yapılır. Kamera -Z yönüne bakar; öndeki nokta negatif z taşır.
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float depth = max(-view_pos.z, 0.001);
	float scale = depth / reference_distance;
	vec3 radial_dir = NORMAL;
	if (dot(VERTEX, VERTEX) > 0.000001) {
		radial_dir = normalize(VERTEX);
	}
	vec3 mixed = mix(NORMAL, radial_dir, normal_smooth);
	vec3 dir = dot(mixed, mixed) > 0.000001 ? normalize(mixed) : NORMAL;
	VERTEX += dir * width * scale;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
