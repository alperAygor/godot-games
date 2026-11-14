class_name FaceView
extends Control
## Müşterinin yüzü: yüz kimliğinden türeyen basit, ayırt edilebilir bir portre (ten, saç, gözlük, bıyık...).
## Aynı kimlik her zaman aynı yüzü verir; kimlik fotoğrafı ve müşteri aynı çizimi kullandığı için karşılaştırılır.
## Altındaki "#numara" oyuncunun bildirimle/kimlikle karşılaştıracağı yüz numarasıdır. Gerçek modüler portreler sonraya.

const SKINS: Array[Color] = [Color("F6D2B0"), Color("E9B98F"), Color("D29B6E"), Color("B57A52"), Color("8A5A3B")]
const HAIRS: Array[Color] = [Color("2B1D14"), Color("5A3A22"), Color("8A5A2B"), Color("B8893B"), Color("8E8E96"), Color("A13B2A")]
const INK := Color(0.23, 0.18, 0.13)

var face_id := 0
var initials := ""
var caption := true
## Konuşurken ağız açılır (0..1); konuşma animasyonu bunu oynatır.
var mouth_open := 0.0:
	set(value):
		mouth_open = value
		queue_redraw()


func setup(id: int, holder_name: String, min_size := 150.0) -> void:
	face_id = id
	initials = ""
	for part in holder_name.split(" "):
		if not part.is_empty():
			initials += part[0]
	custom_minimum_size = Vector2(min_size, min_size)
	queue_redraw()


## Yüz kimliğinden sabit özellikler (testlenebilir): ten, saç rengi, saç biçimi, gözlük, bıyık, ağız eğrisi.
## Çocuk yüzü (daha küçük, gözlüksüz, bıyıksız) ve yaşlı saç rengi olan hikaye kimlikleri.
const CHILD_IDS := [906, 910]
const GREY_HAIR_IDS := [904, 909]


static func traits(id: int) -> Dictionary:
	var h := Seed.fnv1a("face|%d" % id)
	var child := id in CHILD_IDS
	return {
		"child": child, "grey": id in GREY_HAIR_IDS,
		"skin": h % SKINS.size(), "hair": (h / 7) % HAIRS.size(), "style": (h / 53) % 4,
		"glasses": not child and (h / 211) % 4 == 0, "mustache": not child and (h / 977) % 5 == 0, "mouth": (h / 4001) % 3, "eyes": (h / 13001) % 3,
	}


func _draw() -> void:
	var trait_set := traits(face_id)
	var center := size / 2.0 - Vector2(0, size.y * 0.04 if caption else 0.0)
	var radius := minf(size.x, size.y) * (0.41 if caption else 0.46) * (0.8 if trait_set["child"] else 1.0)
	var skin: Color = SKINS[trait_set["skin"]]
	var hair: Color = HAIRS[4] if trait_set["grey"] else HAIRS[trait_set["hair"]]
	var style := int(trait_set["style"])
	# Saç (arkada): uzun saç omuzlara iner.
	if style == 1:
		draw_rect(Rect2(center.x - radius * 1.02, center.y - radius * 0.3, radius * 2.04, radius * 1.45), hair)
	draw_circle(center, radius, skin)
	draw_circle(center, radius, INK, false, 3.0)
	# Saç (önde): kısa / uzun üst kapak, kasket, kel.
	if style != 3:
		# Alın çizgisinin üstünde kalan yay: kapalı çokgen, kirişle kapanır.
		var forehead := 0.5 if style == 0 else (0.42 if style == 1 else 0.3)
		var start := asin(forehead / 0.98)
		var cap_points := PackedVector2Array()
		for i in range(0, 17):
			var angle := PI + start + (PI - 2.0 * start) * i / 16.0
			cap_points.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.98)
		draw_colored_polygon(cap_points, hair if style != 2 else Color("2F4A3A"))
		if style == 2:
			draw_rect(Rect2(center.x - radius * 0.2, center.y - radius * 0.12, radius * 1.15, radius * 0.1), Color("2F4A3A"))
	var eye_gap := radius * (0.36 + 0.06 * int(trait_set["eyes"]))
	var eye_y := center.y - radius * 0.02
	for sign_x in [-1.0, 1.0]:
		var eye_center := Vector2(center.x + sign_x * eye_gap, eye_y)
		draw_circle(eye_center, radius * 0.075, INK)
		if trait_set["glasses"]:
			draw_arc(eye_center, radius * 0.19, 0.0, TAU, 20, INK, 2.5)
	if trait_set["glasses"]:
		draw_line(Vector2(center.x - eye_gap + radius * 0.19, eye_y), Vector2(center.x + eye_gap - radius * 0.19, eye_y), INK, 2.5)
	draw_line(Vector2(center.x, eye_y + radius * 0.05), Vector2(center.x - radius * 0.05, eye_y + radius * 0.32), INK.lightened(0.2), 2.0)
	var mouth_y := center.y + radius * 0.52
	var mouth := int(trait_set["mouth"])
	var mouth_points := PackedVector2Array()
	for i in range(0, 9):
		var t := i / 8.0 - 0.5
		mouth_points.append(Vector2(center.x + t * radius * 0.7, mouth_y + (0.5 - absf(t * 2.0) * 0.5 if mouth == 0 else (-0.2 if mouth == 2 else 0.0)) * radius * 0.0 + (t * t * radius * 0.5 * (1.0 if mouth == 0 else (-1.0 if mouth == 2 else 0.0)))))
	draw_polyline(mouth_points, INK, 3.0)
	if mouth_open > 0.05:
		draw_circle(Vector2(center.x, mouth_y + radius * 0.06), radius * 0.15 * mouth_open, Color("5A1F1A"))
	if trait_set["mustache"]:
		draw_rect(Rect2(center.x - radius * 0.3, mouth_y - radius * 0.2, radius * 0.6, radius * 0.1), hair)
	if caption:
		var font := get_theme_default_font()
		draw_string(font, Vector2(0.0, size.y - 2.0), "#%d" % face_id, HORIZONTAL_ALIGNMENT_CENTER, size.x, maxi(18, int(size.y * 0.16)), INK)
