extends Node
## Ekran sarsıntısı, vuruş donması ve titreşim gibi "juice" efektlerinin merkezi.

var shake_amount := 0.0
var kick := Vector2.ZERO
var time := TimeScale.new()   ## oyun hızının tek sahibi: Engine.time_scale'e YALNIZ buradan yazılır

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
	var ticket := time.begin_hit(slow)
	if ticket < 0:
		return
	_apply_time()
	await get_tree().create_timer(duration, true, false, true).timeout
	time.end_hit(ticket)   # eski/geçersiz bilet etkisiz: yavaş çekim ya da duraklatma araya girdiyse bayat değer yazılmaz
	_apply_time()

func slow_motion(scale: float, duration: float) -> void:
	## Mutlak yavaş çekim (ölüm): `duration` (gerçek sn) sonra kendiliğinden biter; araya giren settle() bunu iptal eder.
	var ticket := time.begin_override(scale)
	_apply_time()
	await get_tree().create_timer(duration, true, false, true).timeout
	time.end_override(ticket)
	_apply_time()

func set_base_scale(scale: float) -> void:
	## Araçlar (scene_probe, smoke_test) oyunu hızlandırmak için Engine.time_scale yerine bunu kullanır.
	time.set_base(scale)
	_apply_time()

func settle_time() -> void:
	## Geçici hız katmanlarını kapatır (duraklatma, devam, kart ekranı, reklam, yeni koşu).
	time.settle()
	_apply_time()

func _apply_time() -> void:
	Engine.time_scale = time.current()

func vibrate(ms: int) -> void:
	if Settings.touch and Settings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func reset() -> void:
	shake_amount = 0.0
	kick = Vector2.ZERO
	settle_time()
