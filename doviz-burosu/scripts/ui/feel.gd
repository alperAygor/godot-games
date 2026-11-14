class_name Feel
extends RefCounted
## "His" yardımcıları: ses, titreşim ve küçük animasyonlar. Ekranlar bunları çağırır; kural içermez.
## Ses dosyaları assets/audio/sfx/<ad>.mp3 (tools/make_sfx.py üretir); dosya yoksa sessiz kalır.
## Titreşim `game/vibration` ayarına bağlıdır. Animasyonlar yerleşimi bozmaz: yalnızca alfa ve ölçek (merkezden) oynar.

const SFX_DIR := "res://assets/audio/sfx/"

## Animasyonlar anında bitsin mi? Ekransız (test/CI) çalıştırmada varsayılan evet; animasyon testleri kapatır.
static var instant := DisplayServer.get_name() == "headless"


static func sfx(sound: String, pitch := 1.0) -> void:
	var audio: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager")
	if audio == null:
		return
	var stream: AudioStream = audio.sfx_stream(sound)  # önbellekli: diskten tekrar okunmaz
	if stream != null:
		audio.play_sfx(stream, pitch)


## Gişenin oda uğultusu: bütün ekranlarda sürekli çalar (Music kanalı, döngü). Ekransız çalıştırmada çalmaz; tekrar çağrılması zararsız.
static func start_ambience() -> void:
	if instant or DisplayServer.get_name() == "headless":
		return
	var path := SFX_DIR + "ambient.mp3"
	if not ResourceLoader.exists(path):
		return
	var audio: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager")
	if audio == null:
		return
	var stream := load(path) as AudioStreamMP3
	stream.loop = true
	audio.play_ambient(stream)


## Konuşma "sesi" (Papers, Please gibi): her harf grubunda kısa bir bip. `voice` 0..1 sesin tizliğini belirler (müşteriye göre sabit).
## Akış koda üretilir (dosya yok); önbellek tutulmaz, çıkışta kaynak kullanımda kalmasın.
static func blip(voice: float) -> void:
	if instant:
		return
	var audio: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager")
	if audio != null:
		audio.play_sfx(audio.blip_stream(voice), 0.97 + randf() * 0.06)


## Düğüm `to` konumuna (üst öğesine göre) kayar.
static func slide_to(control: Control, to: Vector2, seconds := 0.25) -> void:
	if instant or not control.is_inside_tree():
		control.position = to
		return
	control.create_tween().tween_property(control, "position", to, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Kısa titreşim (ms). Masaüstünde ve ayar kapalıyken hiçbir şey yapmaz.
static func haptic(milliseconds: int) -> void:
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("SettingsManager")
	if settings != null and not bool(settings.get_value("game", "vibration")):
		return
	Input.vibrate_handheld(milliseconds)


## Düğüm "pat" diye yerine oturur: hafif büyük + saydam başlar, merkezden küçülerek netleşir.
static func pop_in(control: Control, delay := 0.0, from_scale := 1.12) -> void:
	if instant or not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		control.pivot_offset = control.size / 2.0
		control.scale = Vector2(from_scale, from_scale)
		control.modulate.a = 1.0)
	tween.tween_property(control, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ekranı hafifçe sallar (damga vuruşu). Bitince konum tam sıfırlanır.
static func shake(root: Control, strength := 6.0) -> void:
	var tween := root.create_tween()
	for offset: Vector2 in [Vector2(strength, 0), Vector2(-strength, strength * 0.4), Vector2(strength * 0.5, 0), Vector2.ZERO]:
		tween.tween_property(root, "position", offset, 0.04)


## Damga: ekranın ortasında büyükten oturarak belirir, kısa durur, silinir.
static func stamp(root: Control, text: String, color: Color) -> void:
	var label := Label.new()
	label.name = "StampMark"
	label.text = text
	label.theme_type_variation = &"StampLabel"
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.rotation = -0.2
	root.add_child(label)
	label.scale = Vector2(2.2, 2.2)
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_callback(func() -> void: label.pivot_offset = label.size / 2.0)
	tween.tween_property(label, "modulate:a", 0.92, 0.05)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.35)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)


## Yukarı süzülüp kaybolan kısa yazı (kazanç gibi).
static func float_text(root: Control, text: String, color: Color, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"ToastLabel"
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	label.position = at
	root.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", at.y - 60.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(label.queue_free)
