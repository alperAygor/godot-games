extends Node2D

## Oyun ekranı: ipler, bekleme askısı, sepetler ve sıradaki sepet kuyruğu.
## Kurallar `LaundryBoard` içindedir; bu betik yalnız gösterir ve canlandırır.
## Dokunuşlar mantığa ANINDA işlenir, animasyonlar olay kuyruğundan sırayla oynar;
## böylece hızlı oynayan oyuncu engellenmez (PROJECT_SPEC §2).

const COLORS: Array[Color] = [
	Color("e5484d"), Color("3e8ef7"), Color("f5c02e"), Color("3dbb6e"),
	Color("9b59d0"), Color("f58a3c"), Color("22b8b0"),
]
const SKY_SUNNY_TOP: Color = Color("aee0ff")
const SKY_SUNNY_BOTTOM: Color = Color("eef8e6")
const SKY_STORM_TOP: Color = Color("5d6b80")
const SKY_STORM_BOTTOM: Color = Color("aab4bf")
const ROPE_COLOR: Color = Color("8a6a4a")
const RACK_COLOR: Color = Color("b98a55")
const DANGER_COLOR: Color = Color("e5484d")
const TEXT_COLOR: Color = Color("2a2f3d")

const LINES_TOP: float = 330.0
const LINES_AREA: float = 800.0
const MAX_LINE_SPACING: float = 240.0
const MAX_COLUMN_SPACING: float = 235.0
const BOARD_WIDTH: float = 940.0
const MAX_GARMENT_SIZE: float = 205.0
const LAYER_DROP: float = 16.0
const RACK_Y: float = 1320.0
const RACK_SPACING: float = 175.0
## Askı görselinde 5 kanca vardır; ortadaki ekranın ortasındadır. 4 slotlu seviyede soldaki
## dört kanca kullanılır, "+1 askı" beşinci (en sağdaki) kancayı açar.
const RACK_CENTER_HOOK: float = 2.0
## İpler direklerin iç halkalarına bağlanır.
const ROPE_INSET: float = 100.0
const RACK_GARMENT_SCALE: float = 0.62
const BASKET_Y: float = 1590.0
const BASKET_SIZE: float = 250.0
const BASKET_SPACING: float = 300.0
const BASKET_GARMENT_SCALE: float = 0.42
const QUEUE_Y: float = 1772.0
const QUEUE_DOT: float = 20.0
const QUEUE_SHOWN: int = 6
## Yığın basarken/içine çökerken parçaların sepet içindeki hedef sapmaları.
const ABSORB_DROP_RATIO: float = 0.1
const ABSORB_SCALE: Vector2 = Vector2(0.8, 0.5)
const MS_PER_SECOND: float = 1000.0
const PUFF_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
const PUFF_SPEED_MIN: float = 30.0
const PUFF_SPEED_MAX: float = 95.0
const PUFF_DAMPING: float = 90.0
const PUFF_SCALE_MIN: float = 0.07
const PUFF_SCALE_MAX: float = 0.15
const SPARKLE_SPEED_MIN: float = 110.0
const SPARKLE_SPEED_MAX: float = 300.0
const SPARKLE_GRAVITY: float = 160.0
const SPARKLE_DAMPING: float = 60.0
const SPARKLE_SCALE_MIN: float = 0.05
const SPARKLE_SCALE_MAX: float = 0.13
const PARTICLE_Z: int = 90
## Parçacık boyunca küçülme eğrisinin bitiş değeri (yumuşakça yok olsun, aniden kaybolmasın).
const PARTICLE_END_SCALE: float = 0.25
const LAND_SOUND_DB: float = -10.0
const MIN_TOUCH: float = 126.0
## Mandal ve kumaş seslerinin çeşit sayısı (aynı ses art arda tekrarlamasın).
const SOUND_VARIANTS: int = 3
const RACK_REFUSE_MSEC: int = 350
const COIN_SOUND_DELAY: float = 0.7
## Art arda sepet tamamlandıkça nota perdesi yükselir (yarım ton adımları).
const COMBO_SEMITONE: float = 1.0594631
const COMBO_MAX_STEPS: int = 12
const SPARKLE_COLOR: Color = Color(1.0, 0.96, 0.7)

var _level_number: int = 1
var _level: Dictionary = {}
var _board: LaundryBoard = null
var _views: Dictionary[int, GarmentView] = {}
var _baskets: Array[BasketView] = []
var _basket_items: Array[Array] = []
var _rack_points: Array[Vector2] = []
var _line_ys: Array[float] = []
var _events: Array[Dictionary] = []
var _playing: bool = false
var _center_x: float = 540.0
var _sky: TextureRect = null
var _sky_gradient: Gradient = Gradient.new()
var _sky_weight: float = 0.0
var _world: Node2D = null
var _ui: CanvasLayer = null
var _hud: GameHud = null
var _overlay: Control = null
var _danger: float = 0.0
var debug_level: Dictionary = {}
var _revived: bool = false
var _rack_refuse_until_msec: int = 0
var _backdrop: GardenBackdrop = null
var _combo: int = 0
## Ustalık istatistikleri + zincir: zincirin TEK doğruluk kaynağı (perde, HUD hapı, bonus).
var _run_stats: RunStats = RunStats.new()
var _wind_played: bool = false
## Seviye yeniden başlayınca eski olay korutinleri kendiliğinden çıksın diye sayaç.
var _generation: int = 0
var _line_views: Array[GarmentView] = []
var _flights_end_msec: int = 0
var _applied_sway: float = Motion.SWAY_CALM
var _danger_blend: float = 0.0
var _puffs: Array[CPUParticles2D] = []
var _puff_next: int = 0
var _sparkles: Array[CPUParticles2D] = []
var _sparkle_next: int = 0
var _fade_ramp: Gradient = null
var _shrink_curve: Curve = null
## Prob/geliştirme çalıştırmaları oyuncunun kaydını ezmesin diye kapatılabilir.
## Kayıt Progress autoload'unda; bu bayrak ona iletilir (eski prob uyumu).
var _persist: bool = true:
	set(value):
		_persist = value
		Progress.persist = value
var _eco: EcoFlow = null
## [DAILY] Günlük bulmaca kipi: doluysa seviye dışarıdan gelir; ilerleme/seri/seviye no değişmez.
var _daily_level: Dictionary = {}
## Öğretici (el imleci, tanıtım kartları, boşta ipucu): mantığı tutorial_director.gd'de.
var _tutorial: TutorialDirector = null


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GAME)
	GameManager.back_requested.connect(_on_back)
	_level_number = Progress.level()
	_eco = EcoFlow.new()
	add_child(_eco)
	# Geliştirme/prob: `-- --level=N` ile doğrudan o seviye açılır.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			_level_number = maxi(int(arg.split("=")[1]), 1)
			_persist = false
	_daily_level = DailyPuzzle.take_pending()  # [DAILY] tek seferlik devir
	_center_x = get_viewport_rect().size.x * 0.5
	_build_sky()
	_build_ui()
	_tutorial = TutorialDirector.new()
	add_child(_tutorial)
	_start_level()


func _process(delta: float) -> void:
	var target: float = 0.0
	if _board != null and _board.rack_slots() > 0:
		target = clampf(float(_board.rack_count()) / float(_board.rack_slots()), 0.0, 1.0)
		if _board.is_lost():
			target = 1.0
	_sky_weight = lerpf(_sky_weight, target * target, 1.0 - exp(-3.0 * delta))
	if _backdrop != null:
		_sky_gradient.set_color(0, _backdrop.sky_top(SKY_STORM_TOP, _sky_weight))
		_sky_gradient.set_color(1, _backdrop.sky_bottom(SKY_STORM_BOTTOM, _sky_weight))
		if _world != null:
			_world.modulate = _backdrop.garment_tint
		_backdrop.storm = _sky_weight
		_backdrop.danger = 1.0 if Time.get_ticks_msec() < _rack_refuse_until_msec else _danger
	_update_sway()
	# Tehlike: askıda tek boş slot kalınca askı kırmızı nabız atar. Nabzın şiddeti
	# yumuşakça açılıp kapanır (ani kırmızı parlama rahatsız eder).
	var near_full: bool = _board != null and not _board.is_over() \
		and _board.rack_count() >= _board.rack_slots() - 1
	_danger_blend = lerpf(_danger_blend, 1.0 if near_full else 0.0, 1.0 - exp(-Motion.DANGER_BLEND_RATE * delta))
	_danger = _danger_blend * (0.5 + 0.5 * sin(Time.get_ticks_msec() * Motion.DANGER_PULSE_SPEED))
	queue_redraw()


## Fırtına arttıkça ipteki çamaşırların sallanma çarpanı yükselir. Neden eşikli: her karede
## onlarca materyal parametresi yazmak yerine yalnız anlamlı değişimde yazılır.
func _update_sway() -> void:
	var sway: float = lerpf(Motion.SWAY_CALM, Motion.SWAY_STORM, _sky_weight)
	if absf(sway - _applied_sway) < Motion.SWAY_UPDATE_STEP:
		return
	_applied_sway = sway
	for view: GarmentView in _line_views:
		view.set_sway_strength(sway)


func _unhandled_input(event: InputEvent) -> void:
	if _tutorial != null and _tutorial.input_blocked:
		return
	var position: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		position = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		position = (event as InputEventMouseButton).position
	else:
		return
	if _board == null or _board.is_over():
		return
	if _booster_intercepts(get_canvas_transform().affine_inverse() * position):
		return
	var id: int = _pick(get_canvas_transform().affine_inverse() * position)
	if id != LaundryBoard.EMPTY:
		_tap(id)


## Dokunulan noktadaki en üstteki çamaşır (ipte olanlar arasında).
func _pick(point: Vector2) -> int:
	var best: int = LaundryBoard.EMPTY
	var best_layer: int = -1
	for id: int in _views.keys():
		if not _board.is_on_line(id):
			continue
		var view: GarmentView = _views[id]
		var rect: Rect2 = view.hit_rect()
		rect.position += view.position
		if rect.size.x < MIN_TOUCH:
			rect = rect.grow((MIN_TOUCH - rect.size.x) * 0.5)
		if rect.has_point(point) and view.layer > best_layer:
			best = id
			best_layer = view.layer
	return best


func _tap(id: int) -> void:
	var events: Array[Dictionary] = _board.tap(id)
	if events.is_empty():
		return
	_tutorial.on_tap(id, events)
	# Zincir koptuysa (görünür bir zincir) pil, animasyon kuyruğunda sırası gelince sönsün.
	if _run_stats.record_tap(events) >= RunStats.MIN_VISIBLE_CHAIN:
		events.push_front({"type": RunStats.EVENT_CHAIN_BREAK})
	var first: String = String(events[0]["type"])
	if first != LaundryBoard.EVENT_BLOCKED and first != LaundryBoard.EVENT_LOCKED \
			and first != LaundryBoard.EVENT_RACK_FULL:
		UiData.vibrate(12)
		AudioService.play_variant("pin_click", SOUND_VARIANTS, randf_range(0.94, 1.08), 0.0)
	_events.append_array(events)
	_refresh_open()
	_run_events()


func _refresh_open() -> void:
	for id: int in _views.keys():
		if _board.is_on_line(id):
			_views[id].set_open(_board.is_open(id))
	_refresh_obstacle_views()


func _run_events() -> void:
	if _playing:
		return
	_playing = true
	var generation: int = _generation
	while not _events.is_empty():
		var event: Dictionary = _events.pop_front()
		await _play_event(event)
		# Seviye yeniden başladıysa bu korutin eskidir: kuyruğa/duruma dokunmadan çık.
		if generation != _generation:
			return
	_playing = false


## Zamanlayıcı bekler; seviye bu arada yenilendiyse false döner (çağıran çıkmalı).
func _wait(seconds: float) -> bool:
	var generation: int = _generation
	await get_tree().create_timer(seconds).timeout
	return generation == _generation


## Havadaki son çamaşır oturana kadar bekler (sepet kapanışı/kazanma bundan sonra başlar).
func _wait_flights() -> bool:
	var remaining: float = float(_flights_end_msec - Time.get_ticks_msec()) / MS_PER_SECOND
	if remaining <= 0.0:
		return true
	return await _wait(remaining)


func _play_event(event: Dictionary) -> void:
	match String(event["type"]):
		LaundryBoard.EVENT_BLOCKED:
			AudioService.play_pitched("blocked", randf_range(0.95, 1.05), -6.0)
			_views[int(event["id"])].wobble()
			for blocker: Variant in event["by"] as Array:
				_views[int(blocker)].flash()
		LaundryBoard.EVENT_RACK_FULL:
			# Askı dolu: parça alınamaz. Çamaşır sallanır, askı kısa bir an kırmızıya döner.
			AudioService.play_pitched("blocked", randf_range(0.85, 0.95), -5.0)
			_views[int(event["id"])].wobble()
			_rack_refuse_until_msec = Time.get_ticks_msec() + RACK_REFUSE_MSEC
		LaundryBoard.EVENT_LOCKED:
			AudioService.play_pitched("lock_rattle", randf_range(0.95, 1.05), -5.0)
			_views[int(event["id"])].wobble()
			# Hangi sepetin beklendiğini göster: o renkteki aktif sepet yumuşakça şişer.
			for basket: BasketView in _baskets:
				if basket.visible and basket.color.is_equal_approx(COLORS[int(event["color"]) % COLORS.size()]):
					basket.hop()
		LaundryBoard.EVENT_WRING:
			_views[int(event["id"])].wring()
			AudioService.play_pitched("wring", randf_range(0.95, 1.05))
		LaundryBoard.EVENT_UNLOCK:
			_views[int(event["id"])].unlock()
			AudioService.play_pitched("unlock", 1.0, -4.0)
		LaundryBoard.EVENT_TO_RACK:
			var view: GarmentView = _views[int(event["id"])]
			_leave_line(view)
			_fly(view, _rack_points[int(event["slot"])], RACK_GARMENT_SCALE, 0.0, 0.0)
			view.landed.connect(_on_rack_landed.bind(view), CONNECT_ONE_SHOT)
			await _wait(Motion.stagger(_events.size()))
		LaundryBoard.EVENT_TO_BASKET, LaundryBoard.EVENT_RACK_TO_BASKET:
			var index: int = int(event["basket"])
			var stack_index: int = int(event["index"])
			var flying: GarmentView = _views[int(event["id"])]
			_leave_line(flying)
			_basket_items[index].append(flying)
			# Sepete giderken havada katlanır; sepette katlar üst üste ayrı ayrı durur:
			# her kat hafif döner ve biraz farklı tonda durur.
			flying.z_index = 60 + stack_index
			flying.modulate = Color.WHITE.darkened(Motion.STACK_SHADE * float(2 - stack_index))
			var tilt: float = Motion.STACK_TILT_DEGREES * (1.0 if stack_index % 2 == 0 else -1.0)
			_fly(flying, _baskets[index].slot_position(stack_index), 1.0, _baskets[index].folded_width(), tilt)
			flying.landed.connect(_on_basket_landed.bind(index, stack_index, flying), CONNECT_ONE_SHOT)
			await _wait(Motion.stagger(_events.size()))
		LaundryBoard.EVENT_BASKET_DONE:
			await _complete_basket(int(event["basket"]), int(event.get(RunStats.EVENT_CHAIN_KEY, 1)))
		RunStats.EVENT_CHAIN_BREAK:
			_hud.fade_chain()
		LaundryBoard.EVENT_BASKET_NEW:
			_baskets[int(event["basket"])].enter(_basket_tint(event), int(event.get("cap", LaundryBoard.BASKET_CAPACITY)), bool(event.get("joker", false)))
		LaundryBoard.EVENT_WIN:
			if await _wait_flights():
				await _wait(Motion.WIN_DELAY_SECONDS)
				_show_win()
		LaundryBoard.EVENT_LOSE:
			_announce_lose(event)
			UiData.vibrate(300)
			AudioService.play_pitched("wind", 1.0, -3.0)
			if await _wait_flights():
				await _wait(Motion.LOSE_DELAY_SECONDS)
				_show_lose(int(event.get("remaining", 0)))
		_:
			await _play_obstacle_event(event)


## Çamaşır ipten ayrılır: sallanma listesinden çıkar, aynı ipteki komşular yumuşakça sallanır.
func _leave_line(view: GarmentView) -> void:
	var at: int = _line_views.find(view)
	if at < 0:
		return
	_line_views.remove_at(at)
	for other: GarmentView in _line_views:
		if other.line != view.line:
			continue
		var offset: float = other.position.x - view.position.x
		var reach: float = 1.0 - absf(offset) / Motion.NEIGHBOUR_RADIUS
		if reach > 0.0:
			other.nudge(signf(offset) * Motion.NEIGHBOUR_KICK * reach)


## Zarif yay uçuşu (hazırlık + uçuş + iniş). Ses, kalkış anına hizalanır (mandal fırlayınca).
func _fly(view: GarmentView, target: Vector2, target_scale: float, folded_width: float, tilt: float) -> void:
	view.set_open(true)
	view.z_index = maxi(view.z_index, 50)
	view.fly_to(target, target_scale, folded_width, tilt)
	_flights_end_msec = maxi(_flights_end_msec,
		Time.get_ticks_msec() + int(Motion.total_fly_seconds() * MS_PER_SECOND))
	get_tree().create_timer(Motion.ANTICIPATE_SECONDS).timeout.connect(
		AudioService.play_variant.bind("cloth", SOUND_VARIANTS, randf_range(0.9, 1.1), -6.0))


func _on_rack_landed(view: GarmentView) -> void:
	if is_instance_valid(view):
		AudioService.play_pitched("rack_hang", randf_range(0.94, 1.06), -5.0)


func _on_basket_landed(index: int, stack_index: int, view: GarmentView) -> void:
	if index >= _baskets.size():
		return
	var basket: BasketView = _baskets[index]
	basket.receive(1.0 - 0.2 * float(stack_index))
	basket.set_filled(stack_index + 1)
	if is_instance_valid(view):
		_puff(view.global_position)
	AudioService.play_pitched("fold_puff", randf_range(1.0, 1.12), LAND_SOUND_DB)


## Sepet doldu: yığın aşağı basılır, parıltı patlar, bant nabız atar, parçalar sepete
## karışır; sonra sepet kayıp gider ve yenisi gelir (kayma beklenmez, kuyruk akmaya devam eder).
func _complete_basket(index: int, chain_step: int = 1) -> void:
	if not await _wait_flights():
		return
	var basket: BasketView = _baskets[index]
	var pieces: Array = _basket_items[index]
	# 1) Yığın basar: parçalar birbirine yaklaşır, sepet çöker.
	basket.press(Motion.COMPLETE_PRESS_SECONDS)
	for position_in_stack: int in range(pieces.size()):
		var piece: GarmentView = pieces[position_in_stack] as GarmentView
		var squeezed: Vector2 = basket.slot_position(0) + Vector2(0.0,
			-float(position_in_stack) * basket.size * 0.19 * Motion.COMPLETE_PRESS_RATIO)
		var press: Tween = piece.create_tween().set_parallel(true)
		press.tween_property(piece, "global_position", squeezed, Motion.COMPLETE_PRESS_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		press.tween_property(piece, "scale", Vector2(1.04, 0.88), Motion.COMPLETE_PRESS_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not await _wait(Motion.COMPLETE_PRESS_SECONDS + Motion.COMPLETE_HOLD_SECONDS):
		return
	# 2) Parıltı + bant nabzı + sesler.
	UiData.vibrate(40)
	# Perde artık zamana değil ZİNCİRE bağlı (RunStats tek kaynak): zincir adımı n ise n-1 yarım ton.
	_combo = maxi(chain_step - 1, 0)
	if chain_step >= RunStats.MIN_VISIBLE_CHAIN:
		_hud.show_chain(chain_step)
	AudioService.play_pitched("fold_puff", randf_range(0.96, 1.04))
	AudioService.play_pitched("note", pow(COMBO_SEMITONE, float(mini(_combo, COMBO_MAX_STEPS)) * 2.0), -5.0)
	_sparkle(basket.rest_position + Vector2(0.0, -BASKET_SIZE * 0.3), basket.color)
	basket.pulse_band()
	# 3) Parçalar sepetin içine karışıp solar.
	for garment: Variant in pieces:
		var piece: GarmentView = garment as GarmentView
		var absorb: Tween = piece.create_tween().set_parallel(true)
		absorb.tween_property(piece, "global_position",
			basket.rest_position + Vector2(0.0, -BASKET_SIZE * ABSORB_DROP_RATIO), Motion.COMPLETE_ABSORB_SECONDS)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		absorb.tween_property(piece, "scale", ABSORB_SCALE, Motion.COMPLETE_ABSORB_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		absorb.tween_property(piece, "modulate:a", 0.0, Motion.COMPLETE_ABSORB_SECONDS * 0.7)\
			.set_delay(Motion.COMPLETE_ABSORB_SECONDS * 0.3)
	if not await _wait(Motion.COMPLETE_ABSORB_SECONDS):
		return
	for garment: Variant in pieces:
		(garment as GarmentView).queue_free()
	pieces.clear()
	# 4) Sepet yavaşça kayıp gider; yenisi (BASKET_NEW) kayma bitince gelir.
	basket.leave()


## Yumuşak parıltı patlaması (sepet renginde + sıcak beyaz). Havuzdan; her seferinde yeni düğüm yok.
func _sparkle(at: Vector2, tint: Color) -> void:
	if _sparkles.is_empty():
		return
	for layer_color: Color in [SPARKLE_COLOR, tint.lightened(0.35)]:
		var burst: CPUParticles2D = _sparkles[_sparkle_next]
		_sparkle_next = (_sparkle_next + 1) % _sparkles.size()
		burst.color = layer_color
		burst.global_position = at
		burst.restart()
		burst.emitting = true


## İniş tozu: birkaç yumuşak, solan daire.
func _puff(at: Vector2) -> void:
	if _puffs.is_empty():
		return
	var puff: CPUParticles2D = _puffs[_puff_next]
	_puff_next = (_puff_next + 1) % _puffs.size()
	puff.global_position = at
	puff.restart()
	puff.emitting = true


func _make_emitter(count: int, lifetime: float) -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.one_shot = true
	emitter.emitting = false
	emitter.explosiveness = 0.92
	emitter.amount = count
	emitter.lifetime = lifetime
	emitter.texture = GarmentView.circle_texture()
	emitter.color_ramp = _fade_ramp
	emitter.scale_amount_curve = _shrink_curve
	emitter.z_index = PARTICLE_Z
	_world.add_child(emitter)
	return emitter


## Havuz: seviye başında bir kez kurulur (kare içinde Node üretimi/serbest bırakma yok).
func _build_particles() -> void:
	if _fade_ramp == null:
		_fade_ramp = Gradient.new()
		_fade_ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		_fade_ramp.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.7), Color(1.0, 1.0, 1.0, 0.0)])
		_shrink_curve = Curve.new()
		_shrink_curve.add_point(Vector2(0.0, 1.0))
		_shrink_curve.add_point(Vector2(1.0, PARTICLE_END_SCALE))
	_puffs.clear()
	_sparkles.clear()
	_puff_next = 0
	_sparkle_next = 0
	for i: int in range(Motion.PUFF_POOL):
		var puff: CPUParticles2D = _make_emitter(Motion.PUFF_COUNT, Motion.PUFF_LIFETIME)
		puff.direction = Vector2.UP
		puff.spread = 180.0
		puff.gravity = Vector2.ZERO
		puff.damping_min = PUFF_DAMPING
		puff.damping_max = PUFF_DAMPING
		puff.initial_velocity_min = PUFF_SPEED_MIN
		puff.initial_velocity_max = PUFF_SPEED_MAX
		puff.scale_amount_min = PUFF_SCALE_MIN
		puff.scale_amount_max = PUFF_SCALE_MAX
		puff.color = PUFF_COLOR
		_puffs.append(puff)
	for i: int in range(Motion.SPARKLE_POOL * 2):
		var burst: CPUParticles2D = _make_emitter(Motion.SPARKLE_COUNT, Motion.SPARKLE_LIFETIME)
		burst.direction = Vector2.UP
		burst.spread = 75.0
		burst.gravity = Vector2(0.0, SPARKLE_GRAVITY)
		burst.damping_min = SPARKLE_DAMPING
		burst.damping_max = SPARKLE_DAMPING
		burst.initial_velocity_min = SPARKLE_SPEED_MIN
		burst.initial_velocity_max = SPARKLE_SPEED_MAX
		burst.scale_amount_min = SPARKLE_SCALE_MIN
		burst.scale_amount_max = SPARKLE_SCALE_MAX
		_sparkles.append(burst)


func _start_level() -> void:
	if _world != null:
		_world.queue_free()
	_hide_overlay()
	_generation += 1
	_playing = false
	_flights_end_msec = 0
	_applied_sway = Motion.SWAY_CALM
	_line_views.clear()
	_events.clear()
	_views.clear()
	_slide_home.clear()
	_baskets.clear()
	_basket_items.clear()
	_rack_points.clear()
	_line_ys.clear()
	_revived = false
	_combo = 0
	_run_stats = RunStats.from_balance(Progress.balance_table())
	_hud.hide_chain()
	# Prob, belirli bir durumu (ör. kesin kayıp) sınamak için elle kurulmuş seviye verebilir.
	_level = _daily_level if not _daily_level.is_empty() \
		else (debug_level if not debug_level.is_empty() else LevelGenerator.generate(_level_number))  # [DAILY]
	_board = LaundryBoard.new(_level)
	_eco.on_level_start(_level_number, _board)
	_hud.set_level(_level_number)
	if not _daily_level.is_empty():
		_hud.set_title(UiStrings.DAILY_TITLE)
	_hud.set_coins(Progress.coins())
	_backdrop.set_level(_level_number)
	_hud.set_title_color(_backdrop.hud_text_color(TEXT_COLOR))
	AudioService.play_pitched("level_start", 1.0, -6.0)
	_world = Node2D.new()
	add_child(_world)
	_build_particles()
	_build_lines()
	_build_rack()
	_build_baskets()
	_setup_boosters()
	_setup_rules_hud()
	_refresh_open()
	queue_redraw()
	_tutorial.on_level_started(_level, _board, _views, _baskets, _rack_points)


func _build_lines() -> void:
	var items: Array = _level["items"] as Array
	var lines: int = 1
	var columns: int = 1
	for entry: Variant in items:
		var item: Dictionary = entry as Dictionary
		lines = maxi(lines, int(item["line"]) + 1)
		if int(item["layer"]) == 0:
			columns = maxi(columns, int(float(item["slot"])) + 1)
	var spacing_y: float = minf(MAX_LINE_SPACING, LINES_AREA / float(lines))
	var spacing_x: float = minf(MAX_COLUMN_SPACING, BOARD_WIDTH / float(columns))
	_slide_spacing_x = spacing_x
	var garment_size: float = minf(MAX_GARMENT_SIZE, minf(spacing_x * 0.94, spacing_y * 1.02))
	for line: int in range(lines):
		_line_ys.append(LINES_TOP + spacing_y * float(line))
	for entry: Variant in items:
		var item: Dictionary = entry as Dictionary
		var view: GarmentView = GarmentView.new()
		var layer: int = int(item["layer"])
		view.setup(int(item["id"]), COLORS[int(item["color"]) % COLORS.size()], garment_size,
			int(item.get("kind", 0)), layer)
		view.position = Vector2(
			_center_x + (float(item["slot"]) - float(columns - 1) * 0.5) * spacing_x,
			_line_ys[int(item["line"])] + LAYER_DROP * float(layer))
		view.line = int(item["line"])
		_world.add_child(view)
		_line_views.append(view)
		_views[int(item["id"])] = view
		if bool(item.get("wet", false)):
			view.set_wet(true)
		if bool(item.get("mystery", false)):
			view.set_mystery(true)
		if item.has("lock"):
			view.set_lock(COLORS[int(item["lock"]) % COLORS.size()])
		_decorate_view(view, item, spacing_x, spacing_y)


func _build_rack() -> void:
	var slots: int = _board.rack_slots()
	# 6+ slotta (seri bonusu + devam) askı ekran dışına taşmasın diye ortalanır.
	var center_hook: float = maxf(RACK_CENTER_HOOK, float(slots - 1) * 0.5)
	for slot: int in range(slots):
		_rack_points.append(Vector2(
			_center_x + (float(slot) - center_hook) * RACK_SPACING, RACK_Y))


func _build_baskets() -> void:
	var states: Array[Dictionary] = _board.baskets()
	for index: int in range(states.size()):
		var basket: BasketView = BasketView.new()
		basket.setup(BASKET_SIZE)
		basket.position = Vector2(
			_center_x + (float(index) - float(states.size() - 1) * 0.5) * BASKET_SPACING, BASKET_Y)
		basket.rest_position = basket.position
		_world.add_child(basket)
		_baskets.append(basket)
		_basket_items.append([])
		if states[index].is_empty():
			basket.visible = false
		else:
			basket.set_color(COLORS[int(states[index]["color"]) % COLORS.size()])
			_decorate_basket(basket, states[index])


func _draw() -> void:
	if _board == null:
		return
	var width: float = get_viewport_rect().size.x
	# İpler: hafif sarkan çizgi.
	for y: float in _line_ys:
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in range(25):
			var t: float = float(step) / 24.0
			points.append(Vector2(lerpf(ROPE_INSET, width - ROPE_INSET, t), y - 6.0 + 10.0 * sin(PI * t)))
		draw_polyline(points, ROPE_COLOR, 5.0, true)
	# Sıradaki sepetler: küçük renk noktaları (soldan sağa sıra).
	var queue: Array[int] = _board.queue()
	var shown: int = mini(queue.size(), QUEUE_SHOWN)
	for index: int in range(shown):
		var center: Vector2 = Vector2(
			_center_x + (float(index) - float(shown - 1) * 0.5) * QUEUE_DOT * 3.0, QUEUE_Y)
		var radius: float = QUEUE_DOT * (1.0 if index == 0 else 0.72)
		_draw_queue_dot(index, center, radius, COLORS[queue[index] % COLORS.size()])
	_draw_rules()


func _build_sky() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	_sky_gradient.set_color(0, SKY_SUNNY_TOP)
	_sky_gradient.set_color(1, SKY_SUNNY_BOTTOM)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = _sky_gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	_sky = TextureRect.new()
	_sky.texture = texture
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_sky)
	var garden_layer: CanvasLayer = CanvasLayer.new()
	garden_layer.layer = -5
	add_child(garden_layer)
	_backdrop = GardenBackdrop.new()
	garden_layer.add_child(_backdrop)
	_backdrop.setup(get_viewport_rect().size, RACK_Y)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_hud = GameHud.new()
	_ui.add_child(_hud)
	_hud.pause_requested.connect(_on_pause_requested)
	_hud.set_coins(Progress.coins())


## Düz, çizgisiz düğme (kullanıcı tercihi: minimal modern arayüz).
func _flat_button(text: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(AudioService.play_pitched.bind("ui_soft", 1.0, -4.0))
	var fill: Color = Color("2ec4a6") if primary else Color(0.0, 0.0, 0.0, 0.08)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = fill.darkened(0.08) if state == "pressed" else fill
		box.set_corner_radius_all(40)
		box.content_margin_left = 28.0
		box.content_margin_right = 28.0
		box.content_margin_top = 14.0
		box.content_margin_bottom = 14.0
		button.add_theme_stylebox_override(state, box)
	var text_color: Color = Color.WHITE if primary else TEXT_COLOR
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, text_color)
	button.add_theme_font_size_override("font_size", 32)
	return button


func _show_overlay(title: String, subtitle: String, buttons: Array[Button]) -> void:
	_hide_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_overlay)
	_overlay.modulate.a = 0.0
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.18, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("fbfaf6")
	box.set_corner_radius_all(36)
	box.set_content_margin_all(44.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(680.0, 0.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Panel kapsayıcı içinde durur: kapsayıcının konumunu oynatmak, çapa/yerleşimi bozmadan
	# panelin aşağıdan yumuşakça yükselmesini sağlar.
	var rise: Control = Control.new()
	rise.set_anchors_preset(Control.PRESET_FULL_RECT)
	rise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(rise)
	rise.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", TEXT_COLOR)
	column.add_child(title_label)
	if not subtitle.is_empty():
		var sub_label: Label = Label.new()
		sub_label.text = subtitle
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 30)
		sub_label.add_theme_color_override("font_color", TEXT_COLOR.lerp(Color.WHITE, 0.35))
		column.add_child(sub_label)
	for button: Button in buttons:
		button.custom_minimum_size = Vector2(0.0, 96.0)
		column.add_child(button)
	rise.position.y = Motion.OVERLAY_RISE_DISTANCE
	var intro: Tween = _overlay.create_tween().set_parallel(true)
	intro.tween_property(_overlay, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_property(rise, "position:y", 0.0, Motion.OVERLAY_RISE_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _show_win() -> void:
	if not _daily_level.is_empty():  # [DAILY] normal ilerleme/ekonomi atlanır
		_show_daily_end(true)
		return
	var result: Dictionary = _eco.on_win(_level_number, _board, bool(_level.get("hard", false)), _run_stats)
	var reward: int = int(result["coins"])
	_level_number += 1
	AudioService.play_pitched("win", 1.0, -3.0)
	get_tree().create_timer(COIN_SOUND_DELAY).timeout.connect(
		AudioService.play_pitched.bind("coin", 1.0, -4.0))
	_hud.set_coins(Progress.coins())
	_hide_overlay()
	var sheet: ResultSheet = ResultSheet.win(_ui, reward, _win_tints(),
		_eco.can_watch(AdManager.Placement.DOUBLE_COINS), result)
	# "Devam": geçiş reklamı zamanlaması uygunsa önce o gösterilir, sonra seviye başlar.
	sheet.continue_pressed.connect(func() -> void: _eco.maybe_interstitial(_level_number, _start_level))
	sheet.double_pressed.connect(_on_double_pressed.bind(sheet, reward))
	_track_overlay(sheet)


func _show_lose(remaining: int) -> void:
	if not _daily_level.is_empty():  # [DAILY]
		_show_daily_end(false)
		return
	_eco.on_lose(_level_number, _board, remaining)
	AudioService.play_pitched("lose", 1.0, -3.0)
	_hide_overlay()
	var can_revive: bool = not _revived and _eco.can_watch(AdManager.Placement.REVIVE_EXTRA_SLOT)
	var cost: int = 0 if _revived else int(Progress.balance_table().get("continue_cost", 0))
	var sheet: ResultSheet = ResultSheet.lose(_ui, remaining, can_revive,
		_board.lose_reason() == LaundryBoard.LOSE_MOVES, cost, Progress.coins() >= cost)
	sheet.coins_pressed.connect(_on_revive_coins.bind(cost))
	# "+1 askı" ödüllü reklamla verilir; reklam başarısızsa sayfa açık kalır.
	sheet.revive_pressed.connect(func() -> void:
		_eco.watch(AdManager.Placement.REVIVE_EXTRA_SLOT, _revive, func() -> void: pass))
	sheet.retry_pressed.connect(_start_level)
	_track_overlay(sheet)


## [DAILY] Günlük bulmaca sonu: sonucu DailyFlow gösterir, Progress seviyesi/serisi değişmez.
func _show_daily_end(won: bool) -> void:
	_hide_overlay()
	_track_overlay(DailyFlow.show_end(_ui, _level, won, _win_tints(), _start_level))


## Seviyenin sepet renkleri (kazanma yığını bunlarla boyanır).
func _win_tints() -> Array[Color]:
	var tints: Array[Color] = []
	for color_id: Variant in _level.get("queue", []) as Array:
		var tint: Color = COLORS[int(color_id) % COLORS.size()]
		if not tints.has(tint):
			tints.append(tint)
	return tints


## "2×": ödüllü reklam izlenirse ödül bir kez daha eklenir.
func _on_double_pressed(sheet: ResultSheet, reward: int) -> void:
	var granted: Callable = func() -> void:
		Progress.add_coins(reward)
		_hud.set_coins(Progress.coins())
		if is_instance_valid(sheet):
			sheet.show_doubled(reward * 2)
	_eco.watch(AdManager.Placement.DOUBLE_COINS, granted, func() -> void: pass)


func _track_overlay(sheet: Sheet) -> void:
	_overlay = sheet
	sheet.closed.connect(_on_sheet_closed.bind(sheet))


func _on_sheet_closed(sheet: Sheet) -> void:
	if _overlay == sheet:
		_overlay = null


func _on_pause_requested() -> void:
	if _overlay != null:
		return
	var sheet: PauseSheet = PauseSheet.open(_ui)
	sheet.restart_pressed.connect(_start_level)
	sheet.home_pressed.connect(GameManager.goto_scene.bind(&"home"))
	_track_overlay(sheet)


func _on_double_coins(button: Button, reward: int) -> void:
	button.disabled = true
	var granted: Callable = func() -> void:
		Progress.add_coins(reward)
		button.text = "+%d jeton eklendi" % reward
	var failed: Callable = func() -> void: button.disabled = false
	_eco.watch(AdManager.Placement.DOUBLE_COINS, granted, failed)


func _on_revive_ad(button: Button) -> void:
	button.disabled = true
	var failed: Callable = func() -> void: button.disabled = false
	_eco.watch(AdManager.Placement.REVIVE_EXTRA_SLOT, _revive, failed)


func _on_revive_coins(cost: int) -> void:
	if not _revived and Progress.spend_coins(cost):
		_revive()


## Devam (reklamla ya da jetonla): +1 askı, seviye başına 1 kez.
func _revive() -> void:
	if _revived:
		return
	_revived = true
	_run_stats.note_revive()
	_board.add_rack_slot()
	_refresh_rules_views()
	_rack_points.clear()
	_build_rack()
	var rack: Array[int] = _board.rack()
	for slot: int in range(rack.size()):
		if rack[slot] != LaundryBoard.EMPTY:
			_views[rack[slot]].global_position = _rack_points[slot]
	_hide_overlay()


func _on_back() -> void:
	if _overlay is PauseSheet:
		(_overlay as PauseSheet).close()
	else:
		_on_pause_requested()


# --- Derinleşme: yeni engellerin görünümü ve güçlendiriciler ---------------------------------
# Neden ayrı blok: kurallar `LaundryBoard`/`Boosters` içinde; burada yalnız görünüm bağlantısı
# var. Mevcut akışa yalnız kısa kancalar eklendi (_unhandled_input, _refresh_open, _play_event,
# _start_level, _build_lines); geri kalanı bu bloktadır.

## Çarşaf iki ip arasına yayılır: genişlik = sütun aralığı x kapsadığı sütun, yükseklik = ip aralığı + çamaşır.
const SHEET_WIDTH_FILL: float = 0.96
const SHEET_HEIGHT_FILL: float = 0.92

var _booster_bar: BoosterBar = null
var _boosters: Boosters = Boosters.new()
var _pin_armed: bool = false


## `_build_lines` kancası: çarşaf boyutu, çorap rozeti, boya rozeti.
func _decorate_view(view: GarmentView, item: Dictionary, spacing_x: float, spacing_y: float) -> void:
	if bool(item.get("sheet", false)):
		var span: int = int(item.get("span", 2))
		var span_lines: int = int(item.get("span_lines", 2))
		view.make_sheet(spacing_x * float(span) * SHEET_WIDTH_FILL,
			(spacing_y * float(span_lines - 1) + view.size) * SHEET_HEIGHT_FILL)
		# Çarşaf üst ipe asılır (katman düşüşü yok): iki ipi birden örttüğü okunur.
		view.position.y = _line_ys[int(item["line"])]
	if item.has("sock"):
		view.set_sock()
	if item.has("dye"):
		view.set_dye(int(item["dye"]), COLORS[int(item["color"]) % COLORS.size()])
	_decorate_rules_view(view, item)


## `_refresh_open` kancası: tahtadan okunan sayaçlar ve güçlendirici çubuğu.
func _refresh_obstacle_views() -> void:
	for id: int in _views.keys():
		if _board.is_dye(id) and _board.is_on_line(id):
			_views[id].set_dye_left(_board.dye_left(id))
	_refresh_booster_bar()
	_refresh_rules_views()


## `_play_event` kancası: yeni olay türleri.
func _play_obstacle_event(event: Dictionary) -> void:
	if await _play_rules_event(event):
		return
	var id: int = int(event.get("id", LaundryBoard.EMPTY))
	if not _views.has(id):
		return
	match String(event["type"]):
		LaundryBoard.EVENT_SOCK_WAIT:
			var partner: int = int(event["partner"])
			if _views.has(partner):
				_views[partner].hint()
		LaundryBoard.EVENT_SOCK_STUCK:
			_views[id].set_stuck(true)
			AudioService.play_pitched("lock_rattle", randf_range(0.9, 1.0), -6.0)
		LaundryBoard.EVENT_SOCK_FREE:
			_views[id].set_stuck(false)
			AudioService.play_pitched("unlock", 1.1, -6.0)
		LaundryBoard.EVENT_DYE_TICK:
			_views[id].set_dye_left(int(event["left"]))
		LaundryBoard.EVENT_DYE_BLEED:
			var target: int = int(event["target"])
			_views[id].recolor(COLORS[int(event["color"]) % COLORS.size()])
			if _views.has(target):
				_views[target].recolor(COLORS[int(event["target_color"]) % COLORS.size()])
			AudioService.play_pitched("wring", 0.8, -4.0)
			await _wait(GarmentView.RECOLOR_SECONDS)
		LaundryBoard.EVENT_PIN_REMOVED:
			_views[id].release_pins()
			AudioService.play_pitched("unlock", 1.2, -4.0)


func _setup_boosters() -> void:
	if _booster_bar == null:
		_booster_bar = BoosterBar.new()
		_ui.add_child(_booster_bar)
		_booster_bar.setup(get_viewport_rect().size.x)
		_booster_bar.booster_pressed.connect(_on_booster_pressed)
	_boosters.reset()
	_pin_armed = false
	_booster_bar.set_armed("")
	_board.enable_history()
	_refresh_booster_bar()


func _refresh_booster_bar() -> void:
	if _booster_bar == null or _board == null:
		return
	var usable: Dictionary = {}
	for id: String in Boosters.IDS:
		usable[id] = _boosters.can_use(id, _board)
	_booster_bar.refresh(_level_number, usable)


func _on_booster_pressed(id: String) -> void:
	if _board == null or not Boosters.is_unlocked(id, _level_number):
		return
	match id:
		Boosters.UNDO:
			if _boosters.can_use(id, _board) and _booster_bar.spend(id) and _boosters.undo(_board):
				_run_stats.note_booster()
				_set_pin_armed(false)
				_rebuild_from_board()
		Boosters.PIN_REMOVER:
			# Sökücü iki adımlıdır: önce silahlanır, sonra hedef parçaya dokunulur (o an harcanır).
			_set_pin_armed(not _pin_armed and _boosters.can_use(id, _board) and _booster_bar.count(id) > 0)
		Boosters.EXTRA_SLOT:
			if _boosters.can_use(id, _board) and _booster_bar.spend(id) and _boosters.extra_slot(_board):
				_run_stats.note_booster()
				_rebuild_rack_points()
	_refresh_booster_bar()


func _set_pin_armed(armed: bool) -> void:
	_pin_armed = armed
	_booster_bar.set_armed(Boosters.PIN_REMOVER if armed else "")
	if armed:
		for target: int in Boosters.pin_targets(_board):
			if _views.has(target):
				_views[target].flash()


## `_unhandled_input` kancası: sökücü silahlıyken dokunuş hedef seçer (normal dokunuş olmaz).
func _booster_intercepts(point: Vector2) -> bool:
	if not _pin_armed:
		return false
	var id: int = _pick_pin_target(point)
	_set_pin_armed(false)
	if id != LaundryBoard.EMPTY and _booster_bar.count(Boosters.PIN_REMOVER) > 0:
		var events: Array[Dictionary] = _boosters.pin(_board, id)
		if Boosters.pin_succeeded(events):
			_booster_bar.spend(Boosters.PIN_REMOVER)
			Input.vibrate_handheld(20)
		_events.append_array(events)
		_refresh_open()
		_run_events()
	_refresh_booster_bar()
	return true


## Noktadaki EN ÜSTTEKİ sökülebilir parça: üstteki açık parça kapalı olanı gölgelemesin.
func _pick_pin_target(point: Vector2) -> int:
	var best: int = LaundryBoard.EMPTY
	var best_layer: int = -1
	for id: int in _views.keys():
		if not Boosters.is_pin_target(_board, id):
			continue
		var view: GarmentView = _views[id]
		var rect: Rect2 = view.hit_rect()
		rect.position += view.position
		if rect.size.x < MIN_TOUCH:
			rect = rect.grow((MIN_TOUCH - rect.size.x) * 0.5)
		if rect.has_point(point) and view.layer > best_layer:
			best = id
			best_layer = view.layer
	return best


func _rebuild_rack_points() -> void:
	_rack_points.clear()
	_build_rack()
	var rack: Array[int] = _board.rack()
	for slot: int in range(rack.size()):
		if rack[slot] != LaundryBoard.EMPTY and _views.has(rack[slot]):
			_views[rack[slot]].global_position = _rack_points[slot]


## Geri al sonrası: dünya tahtanın o anki durumundan yeniden kurulur. Neden baştan kurmak:
## yarıda kalan uçuş/sepet korutinlerini tek tek geri sarmak hataya açık; `_generation`
## artınca eski korutinler kendiliğinden çıkar ve görünüm kesin olarak tahtayla eşleşir.
func _rebuild_from_board() -> void:
	if _world != null:
		_world.queue_free()
	_generation += 1
	_playing = false
	_flights_end_msec = 0
	_applied_sway = Motion.SWAY_CALM
	_line_views.clear()
	_events.clear()
	_views.clear()
	_slide_home.clear()
	_baskets.clear()
	_basket_items.clear()
	_rack_points.clear()
	_line_ys.clear()
	_world = Node2D.new()
	add_child(_world)
	_build_particles()
	_build_lines()
	_build_rack()
	_build_baskets()
	# Önce renk/durum (boya takası geri alınmış olabilir), sonra yerleşim: katlanan parçanın
	# katlı dokusu rengini uçuş başında sprite'tan alır.
	var off_line: Dictionary = {}
	for id: int in _board.rack():
		off_line[id] = true
	for index: int in range(_baskets.size()):
		for id: int in _board.basket_contents(index):
			off_line[id] = true
	for id: int in _views.keys().duplicate():
		var view: GarmentView = _views[id]
		if not _board.is_on_line(id) and not off_line.has(id):
			# Tamamlanmış sepette katlanıp gitmiş parça: artık görünmez.
			_line_views.erase(view)
			_views.erase(id)
			view.queue_free()
			continue
		view.recolor(COLORS[_board.color_of(id) % COLORS.size()], false)
		if not _board.is_wet(id):
			view.set_wet(false)
		if _board.lock_color(id) != LaundryBoard.EMPTY and not _board.is_locked(id):
			view.unlock()
	var rack: Array[int] = _board.rack()
	for slot: int in range(rack.size()):
		if rack[slot] != LaundryBoard.EMPTY:
			var hanging: GarmentView = _views[rack[slot]]
			_line_views.erase(hanging)
			hanging.snap_to(_rack_points[slot], RACK_GARMENT_SCALE, 0.0, 0.0)
			if _board.is_sock_stuck(rack[slot]):
				hanging.set_stuck(true)
	for index: int in range(_baskets.size()):
		var contents: Array[int] = _board.basket_contents(index)
		for stack_index: int in range(contents.size()):
			var folded: GarmentView = _views[contents[stack_index]]
			_line_views.erase(folded)
			folded.z_index = 60 + stack_index
			folded.modulate = Color.WHITE.darkened(Motion.STACK_SHADE * float(2 - stack_index))
			var tilt: float = Motion.STACK_TILT_DEGREES * (1.0 if stack_index % 2 == 0 else -1.0)
			folded.snap_to(_baskets[index].slot_position(stack_index), 1.0, _baskets[index].folded_width(), tilt)
			_basket_items[index].append(folded)
		_baskets[index].set_filled(contents.size())
	_refresh_open()
	AudioService.play_pitched("cloth", 0.9, -6.0)


# --- Derinleşme 2: kural çeşitlemeleri ve seviye kipleri --------------------------------------
# Neden ayrı blok: kurallar `LaundryBoard` içinde; burada yalnız görünüm bağlantısı var. Mevcut
# akışa kısa kancalar eklendi (_play_event: BASKET_NEW/LOSE, _build_baskets, _draw, _start_level,
# _revive, _decorate_view, _refresh_obstacle_views, _play_obstacle_event); geri kalanı buradadır.

## Kısa askıda kullanılamayan kancaların üstüne konan soluk disk.
const RACK_CLOSED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const RACK_CLOSED_RADIUS: float = 34.0
## Diskin ortasındaki koyu kısa çizgi: "bu kanca kapalı".
const RACK_CLOSED_MARK: Color = Color("9aa3af")
const RACK_CLOSED_MARK_RATIO: float = 0.55
const RACK_VISIBLE_HOOKS: int = 5
## Kuyruk: büyük sepet hap biçiminde (yatay uzun), joker gökkuşağı çiçeği.
const QUEUE_BIG_STRETCH: float = 0.6
const QUEUE_JOKER_PETALS: int = 6
const QUEUE_JOKER_PETAL_RATIO: float = 0.5
const QUEUE_JOKER_CORE_RATIO: float = 0.8
## Joker çiçeği normal noktadan biraz iri: kuyrukta ilk bakışta seçilsin.
const QUEUE_JOKER_SCALE: float = 1.3
const ANNOUNCE_FONT: int = 56
const ANNOUNCE_Y_RATIO: float = 0.42
const ANNOUNCE_PAD: float = 36.0
const ANNOUNCE_FILL: Color = Color(1.0, 1.0, 1.0, 0.94)
const LOSE_MOVES_TEXT: String = "Hamle bitti"

var _rules_hud: RulesHud = null
## Yeniden kurulumdan sonraki ilk tazelemede zincir/rüzgâr/askı durumları yerleştirilir (o an
## tüm görünümler hazırdır).
var _rules_dirty: bool = false
var _announce: Label = null


func _setup_rules_hud() -> void:
	if _rules_hud == null:
		_rules_hud = RulesHud.new()
		_ui.add_child(_rules_hud)
		_rules_hud.setup(get_viewport_rect().size.x, COLORS)
	if _announce != null:
		_announce.queue_free()
		_announce = null
	_rules_hud.start(_board)


## `_build_baskets` kancası: büyük/joker sepet görünümü (yeniden kurulumda da).
func _decorate_basket(basket: BasketView, state: Dictionary) -> void:
	basket.set_capacity(int(state.get("cap", LaundryBoard.BASKET_CAPACITY)))
	var is_joker: bool = bool(state.get("joker", false))
	basket.set_joker(is_joker)
	if is_joker:
		if int(state["color"]) == LaundryBoard.EMPTY:
			basket.set_color(BasketView.JOKER_BAND)
		else:
			basket.fix_joker(COLORS[int(state["color"]) % COLORS.size()])


## BASKET_NEW olayının bant rengi: rengini almamış joker beyaz banttır.
func _basket_tint(event: Dictionary) -> Color:
	if bool(event.get("joker", false)) and int(event["color"]) == LaundryBoard.EMPTY:
		return BasketView.JOKER_BAND
	return COLORS[int(event["color"]) % COLORS.size()]


## `_draw` kancası: kuyruk noktası. Joker = altı renkli küçük çiçek (asıl rengi gizli kalır),
## büyük sepet = yatay hap (iki daire + dolgu).
func _draw_queue_dot(index: int, center: Vector2, radius: float, tint: Color) -> void:
	match _board.queue_kind(index):
		LaundryBoard.KIND_JOKER:
			var petal: float = radius * QUEUE_JOKER_SCALE * QUEUE_JOKER_PETAL_RATIO
			for step: int in range(QUEUE_JOKER_PETALS):
				var angle: float = TAU * float(step) / float(QUEUE_JOKER_PETALS)
				draw_circle(center + Vector2.from_angle(angle) * (radius * QUEUE_JOKER_SCALE - petal), petal,
					BasketView.JOKER_TINTS[step % BasketView.JOKER_TINTS.size()], true, -1.0, true)
			draw_circle(center, petal * QUEUE_JOKER_CORE_RATIO, Color.WHITE, true, -1.0, true)
		LaundryBoard.KIND_BIG:
			var reach: Vector2 = Vector2(radius * QUEUE_BIG_STRETCH, 0.0)
			draw_line(center - reach, center + reach, tint, radius * 2.0, true)
			draw_circle(center - reach, radius, tint, true, -1.0, true)
			draw_circle(center + reach, radius, tint, true, -1.0, true)
		_:
			draw_circle(center, radius, tint, true, -1.0, true)


## `_draw` kancası: kısa askıda kullanılamayan kancalar soluk bir diskle kapatılır.
func _draw_rules() -> void:
	if _board.mode() != LaundryBoard.MODE_SHORT_RACK:
		return
	var slots: int = _board.rack_slots()
	for slot: int in range(slots, RACK_VISIBLE_HOOKS):
		var at: Vector2 = Vector2(_center_x + (float(slot) - RACK_CENTER_HOOK) * RACK_SPACING, RACK_Y)
		draw_circle(at, RACK_CLOSED_RADIUS, RACK_CLOSED_COLOR, true, -1.0, true)
		var reach: Vector2 = Vector2(RACK_CLOSED_RADIUS * RACK_CLOSED_MARK_RATIO, 0.0)
		draw_line(at - reach, at + reach, RACK_CLOSED_MARK, RACK_CLOSED_RADIUS * 0.28, true)


## `_decorate_view` kancası: leke rozeti ve patronun ikinci ekranı (sağda, ekran dışında bekler).
func _decorate_rules_view(view: GarmentView, item: Dictionary) -> void:
	var id: int = int(item["id"])
	_decorate_slide_view(view, item)
	if _board.is_stained(id) and _board.is_on_line(id):
		view.set_stain(true)
	if _board.is_hidden(id):
		view.position.x += get_viewport_rect().size.x
	_rules_dirty = true


## `_refresh_obstacle_views` kancası: gösterge ve rüzgâr rozetleri tahtadan okunur.
func _refresh_rules_views() -> void:
	if _board == null:
		return
	if _rules_dirty:
		_rules_dirty = false
		_place_rules_state()
	if _rules_hud != null:
		_rules_hud.refresh(_board)
	var steps: Array[Vector2i] = _board.wind_steps()
	for step: int in range(_board.wind_done(), steps.size()):
		var mover: int = steps[step].x
		if _views.has(mover) and _views.has(steps[step].y) and _board.is_on_line(mover):
			_views[mover].set_wind(_views[steps[step].y].position.x - _views[mover].position.x,
				step == _board.wind_done())


## Kurulum sonrası tek seferlik: zincir hapları, esmiş rüzgârlar (geri al sonrası), askıdaki
## kuruyan lekeliler.
func _place_rules_state() -> void:
	for id: int in _views.keys():
		var partner: int = _board.chain_partner(id)
		if partner != LaundryBoard.EMPTY and _views.has(partner) and _board.is_on_line(id) \
				and _board.is_on_line(partner) and _views[id].position.x < _views[partner].position.x:
			_views[id].set_chain(_views[partner].position - _views[id].position)
	var steps: Array[Vector2i] = _board.wind_steps()
	for step: int in range(steps.size()):
		if _board.wind_applied(step) and _views.has(steps[step].x) and _views.has(steps[step].y) \
				and _board.is_on_line(steps[step].x):
			_views[steps[step].x].blow_over(_views[steps[step].y].position, _views[steps[step].y].z_index, false)
	for id: int in _board.drying_ids():
		if _views.has(id):
			_views[id].set_stain(true)
			_views[id].set_drying(true)


## `_play_obstacle_event` kancası: yeni olay türleri. Döndürür: olay burada işlendi mi.
func _play_rules_event(event: Dictionary) -> bool:
	if _play_slide_event(event):
		return true
	var id: int = int(event.get("id", LaundryBoard.EMPTY))
	match String(event["type"]):
		LaundryBoard.EVENT_JOKER_FIX:
			var index: int = int(event["basket"])
			if index < _baskets.size():
				_baskets[index].fix_joker(COLORS[int(event["color"]) % COLORS.size()])
				AudioService.play_pitched("unlock", 1.15, -5.0)
		LaundryBoard.EVENT_STAIN_WAIT:
			if _views.has(id):
				_views[id].set_drying(true)
		LaundryBoard.EVENT_STAIN_DRY:
			if _views.has(id):
				_views[id].dry_stain()
				AudioService.play_pitched("fold_puff", 1.2, -8.0)
		LaundryBoard.EVENT_CHAIN_DROP:
			for chained: int in [id, int(event["by"])]:
				if _views.has(chained):
					_views[chained].release_chain()
			AudioService.play_pitched("lock_rattle", 1.1, -6.0)
		LaundryBoard.EVENT_WIND_TICK:
			if _views.has(id):
				_views[id].wind_pulse()
		LaundryBoard.EVENT_WIND:
			if _views.has(id):
				_views[id].clear_wind()
				if bool(event["effective"]) and _views.has(int(event["target"])):
					_views[id].blow_over(_views[int(event["target"])].position, _views[int(event["target"])].z_index)
					AudioService.play_pitched("wind", 1.3, -8.0)
					await _wait(Motion.WIND_FLIP_SECONDS)
		LaundryBoard.EVENT_ORDER_DONE, LaundryBoard.EVENT_ORDER_BROKEN:
			if _rules_hud != null:
				(_rules_hud.mode_pill() as RulesHud.Pill).pulse()
		LaundryBoard.EVENT_SCREEN:
			await _slide_in_screen(int(event["screen"]))
		_:
			return false
	return true


## Patron: ilk ekran boşaldı; ikinci ekranın çamaşırları sağdan kayarak yerine gelir.
func _slide_in_screen(screen: int) -> void:
	if not await _wait_flights():
		return
	if not await _wait(Motion.SCREEN_SLIDE_DELAY):
		return
	var width: float = get_viewport_rect().size.x
	AudioService.play_pitched("wind", 0.9, -6.0)
	for id: int in _views.keys():
		if _board.screen_of(id) != screen or not _board.is_on_line(id):
			continue
		var view: GarmentView = _views[id]
		var slide: Tween = view.create_tween()
		slide.tween_property(view, "position:x", view.position.x - width, Motion.SCREEN_SLIDE_SECONDS)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait(Motion.SCREEN_SLIDE_SECONDS)


## Kayıp nedeni hamle bittiyse sonuç sayfasından önce kısa, açık bir duyuru.
func _announce_lose(event: Dictionary) -> void:
	if String(event.get("reason", "")) != LaundryBoard.LOSE_MOVES:
		return
	if _announce != null:
		_announce.queue_free()
	_announce = Label.new()
	_announce.text = LOSE_MOVES_TEXT
	_announce.add_theme_font_size_override("font_size", ANNOUNCE_FONT)
	_announce.add_theme_color_override("font_color", DANGER_COLOR)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = ANNOUNCE_FILL
	box.set_corner_radius_all(int(ANNOUNCE_FONT))
	box.set_content_margin_all(ANNOUNCE_PAD)
	box.anti_aliasing = true
	_announce.add_theme_stylebox_override("normal", box)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(_announce)
	var view: Vector2 = get_viewport_rect().size
	_announce.reset_size()
	_announce.position = Vector2((view.x - _announce.size.x) * 0.5, view.y * ANNOUNCE_Y_RATIO)
	_announce.pivot_offset = _announce.size * 0.5
	_announce.scale = Vector2.ONE * 0.8
	_announce.modulate.a = 0.0
	var show: Tween = _announce.create_tween().set_parallel(true)
	show.tween_property(_announce, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)
	show.tween_property(_announce, "scale", Vector2.ONE, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.chain().tween_interval(Motion.ANNOUNCE_SECONDS)
	show.chain().tween_property(_announce, "modulate:a", 0.0, Motion.OVERLAY_FADE_SECONDS)


# --- Sürgülü ip: üst sıra birkaç hamlede bir yana kayar ve geri gelir -------------------------
## Kural `LaundryBoard` içindedir (faz tabloları); burada yalnız kayan parçaların yeri ve rozeti.

const SLIDE_SECONDS: float = 0.42
const SLIDE_BADGE_RATIO: float = 0.3
const SLIDE_BADGE_ICON: String = "lucide/rotate-ccw"
const SLIDE_BADGE_INK: Color = Color("2a2f3d")
var _slide_spacing_x: float = 0.0
## Kayan parça -> [faz 0'daki x, yön]; geri al/yeniden kurulumda doğru faza yerleştirmek için.
var _slide_home: Dictionary = {}


func _decorate_slide_view(view: GarmentView, item: Dictionary) -> void:
	if not item.has("slide"):
		return
	var id: int = int(item["id"])
	var shift: float = float(item["slide"])
	_slide_home[id] = Vector2(view.position.x, shift)
	# Geri al sonrası görünümler baştan kurulur: o anki faza göre yerleşir.
	view.position.x += shift * _slide_spacing_x * float(_board.slide_phase())
	var badge: Node2D = Node2D.new()
	badge.position = Vector2(0.0, -view.size * 0.02)
	badge.z_index = 2
	view.add_child(badge)
	var disc: Sprite2D = Sprite2D.new()
	disc.texture = GarmentView.circle_texture()
	disc.scale = Vector2.ONE * (view.size * SLIDE_BADGE_RATIO / float(GarmentView.CIRCLE_TEXTURE_SIZE))
	disc.modulate = Color(1.0, 1.0, 1.0, 0.94)
	badge.add_child(disc)
	var icon: Sprite2D = Sprite2D.new()
	icon.texture = Icons.texture(SLIDE_BADGE_ICON)
	if icon.texture != null:
		icon.scale = Vector2.ONE * (view.size * SLIDE_BADGE_RATIO * 0.62 / icon.texture.get_size().x)
	icon.modulate = SLIDE_BADGE_INK
	badge.add_child(icon)


func _play_slide_event(event: Dictionary) -> bool:
	match String(event["type"]):
		LaundryBoard.EVENT_SLIDE_TICK:
			return true
		LaundryBoard.EVENT_SLIDE:
			var phase: float = float(event["phase"])
			var moved: bool = false
			for id: Variant in _slide_home.keys():
				var view: GarmentView = _views.get(int(id)) as GarmentView
				# Uçmaya başlamış (ipten ayrılmış) parça kaydırılmaz.
				if view == null or not is_instance_valid(view) or not _board.is_on_line(int(id)):
					continue
				var home: Vector2 = _slide_home[id] as Vector2
				var tween: Tween = view.create_tween()
				tween.tween_property(view, "position:x", home.x + home.y * _slide_spacing_x * phase, SLIDE_SECONDS)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				view.nudge(Motion.NEIGHBOUR_KICK)
				moved = true
			if moved:
				AudioService.play_pitched("cloth", 0.8, -5.0)
			_refresh_open()
			return true
	return false

