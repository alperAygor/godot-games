class_name Juice
extends RefCounted

## Tekrar eden "juice" animasyonlari. Hepsini tek yerden yonetmek, her sahnede
## ayni tween zincirini yeniden yazmayi bitirir.
##
## Hepsi TWEEN_PAUSE_PROCESS ile calisir: sahne duraklatildiginda da oynar
## (hata ekrani, reklam anı vb.). Donen Tween cagiran tarafindan iptal edilebilir.

static func _tween(host: Node) -> Tween:
	var tween: Tween = host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


## Kucukten buyuyerek belirme (menuler, popup'lar).
static func pop_in(node: Control, from_scale: float = 0.86, duration: float = 0.26) -> Tween:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from_scale
	node.modulate.a = 0.0
	var tween: Tween = _tween(node)
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE * 1.04, duration * 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration * 0.5)
	tween.chain().tween_property(node, "scale", Vector2.ONE, duration * 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## 3D nesne icin ezilme-gerilme: tabana oturan modellerde dogru okunur
## (origin alt-merkez oldugu icin nesne yerden kopmaz).
static func squash(node: Node3D, strength: float = 1.0) -> Tween:
	var base: Vector3 = node.scale
	var squash_scale: Vector3 = base * Vector3(1.0 + 0.24 * strength, 1.0 - 0.30 * strength, 1.0 + 0.24 * strength)
	var stretch_scale: Vector3 = base * Vector3(1.0 - 0.06 * strength, 1.0 + 0.12 * strength, 1.0 - 0.06 * strength)
	var tween: Tween = _tween(node)
	tween.tween_property(node, "scale", squash_scale, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", stretch_scale, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", base, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween


## Konumda sonumlenen titreme (carpma, hata, reddetme).
static func shake(node: Node3D, amplitude: float = 0.018, duration: float = 0.22,
		steps: int = 4) -> Tween:
	var base: Vector3 = node.position
	var tween: Tween = _tween(node)
	var slice: float = duration / float(steps * 2)
	for i: int in steps:
		var decay: float = 1.0 - (float(i) / float(steps))
		var offset: Vector3 = Vector3(amplitude * decay, 0.0, 0.0)
		tween.tween_property(node, "position", base + offset, slice)
		tween.tween_property(node, "position", base - offset, slice)
	tween.tween_property(node, "position", base, slice)
	return tween


## Sonsuz yuzme dongusu (menude bekleyen nesneler, odul ikonlari).
static func float_loop(node: Node3D, height: float = 0.04, period: float = 2.0) -> Tween:
	var base: Vector3 = node.position
	var tween: Tween = _tween(node)
	tween.set_loops()
	tween.tween_property(node, "position", base + Vector3(0.0, height, 0.0), period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position", base, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## Arayuz solma gecisi.
static func fade(node: CanvasItem, to_alpha: float = 0.0, duration: float = 0.2) -> Tween:
	var tween: Tween = _tween(node)
	tween.tween_property(node, "modulate:a", to_alpha, duration).set_trans(Tween.TRANS_SINE)
	return tween
