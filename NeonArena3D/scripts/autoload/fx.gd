extends Node
## Ekran sarsıntısı, vuruş donması ve titreşim gibi "juice" efektlerinin merkezi.

var shake_amount := 0.0
var kick := Vector2.ZERO
var _stopping := false
var _base_scale := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func shake(amount: float) -> void:
	if not Settings.shake:
		amount *= 0.25
	shake_amount = maxf(shake_amount, minf(amount, 30.0))

func punch(direction: Vector2, amount: float) -> void:
	## Yönlü kamera tepmesi (atış, darbe).
	kick += direction * amount

func tick(delta: float) -> void:
	shake_amount = maxf(0.0, shake_amount - delta * (26.0 + shake_amount * 1.6))
	kick = kick.lerp(Vector2.ZERO, clampf(delta * 14.0, 0.0, 1.0))

func offset() -> Vector2:
	var out := kick
	if shake_amount > 0.01:
		out += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount
	return out

func hitstop(duration := 0.045, slow := 0.12) -> void:
	if _stopping:
		return
	_stopping = true
	_base_scale = Engine.time_scale
	Engine.time_scale = _base_scale * slow
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = _base_scale
	_stopping = false

func vibrate(ms: int) -> void:
	if Settings.touch and Settings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func reset() -> void:
	shake_amount = 0.0
	kick = Vector2.ZERO
	Engine.time_scale = 1.0
	_stopping = false
