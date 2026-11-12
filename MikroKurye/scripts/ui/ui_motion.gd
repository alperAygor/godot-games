class_name UiMotion
extends RefCounted

## UI mikro-etkileşimleri: basışta küçülme, kart girişi, ekran solması.
## Juice (scripts/core) 3D/2D ilkellerini sunar; bu katman UI sahne ritmini kurar.
## Hepsi Tween tabanlı ve kısa süreli — oyun hissini bozmadan geri bildirim verir.
## Tüm süre/ölçek sabitleri burada ya da data/theme.json'da yaşar (sihirli sayı yok).

const PRESS_SCALE: float = 0.96
const PRESS_SPRING: float = 0.14
const FADE_IN_SECONDS: float = 0.18
const STAGGER_PER_ITEM: float = 0.04
## Nefes/pulse alan düğmeler basış ölçeği animasyonunu atlar; iki tween aynı
## `scale` üzerinde çakışıp kare kare titremesin.
const NO_PRESS_SCALE_GROUP: String = "ui_no_press_scale"
## Birincil düğme "nefes": çok hafif, yavaş (±%1.5, 2.4 sn).
const BREATHE_SCALE_AMPLITUDE: float = 0.015
const BREATHE_PERIOD_SECONDS: float = 2.4
## Kart/çip girişi: yumuşak yukarı kayma (stagger 40 ms, 220 ms, ease-out).
const SLIDE_OFFSET_PX: float = 26.0
const SLIDE_IN_SECONDS: float = 0.22
## Cüzdan çipi değer değişimi: ufak pop + renk parlaması.
const CHIP_POP_SCALE: float = 1.08
const CHIP_POP_SECONDS: float = 0.26
## Yetersiz bakiye geri bildirimi: kısa yatay titreme + kırmızımsı flaş.
const DENY_SHAKE_OFFSET_PX: float = 8.0
const DENY_SHAKE_SECONDS: float = 0.32
const DENY_FLASH_COLOR: Color = Color(1.0, 0.72, 0.72)
## "Ödülü 2× Yap" nabzı: hafif, orta hız.
const PULSE_SCALE_AMPLITUDE: float = 0.02
const PULSE_PERIOD_SECONDS: float = 1.2


## Basılıyken anında 0.96'ya küçül, bırakınca geri yaylan. Hover'dan bağımsız.
static func press_feedback(button: BaseButton) -> void:
	# Nefes/pulse ile canlandırılan düğmelerde ölçek bu yardımcıya bırakılmaz;
	# aksi hâlde basış geri bildirimi ile döngü tween'i aynı özelliği paylaşır.
	if button.is_in_group(NO_PRESS_SCALE_GROUP):
		return
	if button.button_down.is_connected(_on_down.bind(button)):
		return
	button.button_down.connect(_on_down.bind(button))
	button.button_up.connect(_on_up.bind(button))


static func _on_down(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * PRESS_SCALE


static func _on_up(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, PRESS_SPRING) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ekran kökünün yumuşak girişi (hızlı fade; geçiş hissi verir).
static func fade_in(node: CanvasItem, duration: float = FADE_IN_SECONDS) -> void:
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Düğme "nefes"i: 1.0 <-> 1+amplitude arasında yavaş ölçek döngüsü.
## Düğme sahneyle birlikte yok olur; tween düğüme bağlıdır (sızıntı yok).
static func breathe(node: Control,
		amplitude: float = BREATHE_SCALE_AMPLITUDE,
		period: float = BREATHE_PERIOD_SECONDS) -> void:
	_scale_loop(node, amplitude, period)


## Düğme "nabzı": nefesin daha hızlı/sık versiyonu (ödül düğmeleri için).
static func pulse(node: Control,
		amplitude: float = PULSE_SCALE_AMPLITUDE,
		period: float = PULSE_PERIOD_SECONDS) -> void:
	_scale_loop(node, amplitude, period)


## Ortak ölçek döngüsü: yarım periyot büyür, yarım periyot küçülür.
static func _scale_loop(node: Control, amplitude: float, period: float) -> void:
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var half: float = maxf(period * 0.5, 0.001)
	var peak: float = 1.0 + maxf(amplitude, 0.0)
	var tween: Tween = node.create_tween()
	tween.set_loops()
	tween.tween_property(node, "scale", Vector2.ONE * peak, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Kartların kademeli belirmesi: önce şeffaf + küçük, sırayla pop.
## Konteyner çocuklarında `position` güvenilmez; ölçek+alfa kullanılır.
static func stagger_pop(nodes: Array[Control]) -> void:
	var index: int = 0
	for node: Control in nodes:
		node.pivot_offset = node.size * 0.5
		node.modulate.a = 0.0
		node.scale = Vector2.ONE * 0.92
		_animate_in(node, float(index) * STAGGER_PER_ITEM)
		index += 1


## Kartların yumuşak YUKARI kayarak belirmesi. Konteyner `position`'ı sahiplendiği
## için hedef konum ilk yerleşimden (bir-iki kare) SONRA okunur; kaydırma o zaman
## başlar. İlk karelerde kartlar yalnızca şeffaftır, sahne akışı gecikmez.
static func stagger_slide(nodes: Array[Control],
		offset: float = SLIDE_OFFSET_PX) -> void:
	for node: Control in nodes:
		node.modulate.a = 0.0
	var tree: SceneTree = _tree()
	if tree == null:
		# Main loop yoksa (izole test) yine de görünür olsunlar: eski pop yeter.
		stagger_pop(nodes)
		return
	await tree.process_frame
	await tree.process_frame
	var index: int = 0
	for node: Control in nodes:
		if not is_instance_valid(node):
			index += 1
			continue
		var base: Vector2 = node.position
		node.position = base + Vector2(0.0, offset)
		var tween: Tween = node.create_tween()
		tween.tween_interval(float(index) * STAGGER_PER_ITEM)
		tween.set_parallel(true)
		tween.tween_property(node, "position:y", base.y, SLIDE_IN_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "modulate:a", 1.0, SLIDE_IN_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		index += 1


## Tek seferlik ölçek "pop"u (satın alma başarısı, pip dolumu gibi).
static func pop(node: Control, scale: float = 1.04) -> void:
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * scale, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Cüzdan çipi değer değişince: ufak pop + renk parlaması. Etiket `text`'i çağıran
## tarafta EŞZAMANLI doğru değere kurulur (probe determinizmi); bu yalnız görsel.
static func chip_pop(chip: Control, glow: Color = Color.WHITE) -> void:
	if not is_instance_valid(chip):
		return
	chip.pivot_offset = chip.size * 0.5
	var tween: Tween = chip.create_tween()
	tween.tween_property(chip, "scale", Vector2.ONE * CHIP_POP_SCALE, CHIP_POP_SECONDS * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(chip, "modulate", glow, CHIP_POP_SECONDS * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(chip, "scale", Vector2.ONE, CHIP_POP_SECONDS * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(chip, "modulate", Color.WHITE, CHIP_POP_SECONDS * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Yetersiz bakiye: kart kısa yatay titrer ve kırmızımsı flaş söner.
static func deny_feedback(node: Control) -> void:
	if not is_instance_valid(node):
		return
	var base: Vector2 = node.position
	node.modulate = DENY_FLASH_COLOR
	var shake: Tween = node.create_tween()
	var step: float = DENY_SHAKE_SECONDS * 0.25
	shake.tween_property(node, "position:x", base.x + DENY_SHAKE_OFFSET_PX, step) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shake.tween_property(node, "position:x", base.x - DENY_SHAKE_OFFSET_PX, step * 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake.tween_property(node, "position:x", base.x, step) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var flash: Tween = node.create_tween()
	flash.tween_property(node, "modulate", Color.WHITE, DENY_SHAKE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func _animate_in(node: Control, delay: float) -> void:
	var tween: Tween = node.create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _tree() -> SceneTree:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null
