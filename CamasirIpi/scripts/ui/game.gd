extends Node2D

## Oyun ekranı: ipler, bekleme askısı, sepetler ve sıradaki sepet kuyruğu.
## Kurallar `LaundryBoard` içindedir; bu betik yalnız gösterir ve canlandırır.
## Dokunuşlar mantığa ANINDA işlenir, animasyonlar olay kuyruğundan sırayla oynar;
## böylece hızlı oynayan oyuncu engellenmez (PROJECT_SPEC §2).

const SAVE_PATH: String = "user://progress.cfg"
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
const RACK_GARMENT_SCALE: float = 0.62
const BASKET_Y: float = 1590.0
const BASKET_SIZE: float = 250.0
const BASKET_SPACING: float = 300.0
const BASKET_GARMENT_SCALE: float = 0.42
const QUEUE_Y: float = 1800.0
const QUEUE_DOT: float = 20.0
const QUEUE_SHOWN: int = 6
const FLIGHT_SECONDS: float = 0.28
const FLIGHT_ARC: float = 110.0
const FLIGHT_STAGGER: float = 0.1
const FOLD_SECONDS: float = 0.45
const BASKET_SLIDE: float = 320.0
const WIN_COINS: int = 20
const HARD_WIN_COINS: int = 40
const MIN_TOUCH: float = 126.0
## Art arda sepet tamamlandıkça nota perdesi yükselir (yarım ton adımları).
const COMBO_SEMITONE: float = 1.0594631
const COMBO_RESET_SECONDS: float = 4.0
const COMBO_MAX_STEPS: int = 12
const SPARKLE_COLOR: Color = Color(1.0, 0.96, 0.7)
const STACK_TILT_DEGREES: float = 4.0
const STACK_SHADE: float = 0.07

var _level_number: int = 1
var _coins: int = 0
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
var _level_label: Label = null
var _overlay: Control = null
var _danger: float = 0.0
var _revived: bool = false
var _backdrop: GardenBackdrop = null
var _combo: int = 0
var _last_fold_msec: int = 0
var _wind_played: bool = false
## Prob/geliştirme çalıştırmaları oyuncunun kaydını ezmesin diye kapatılabilir.
var _persist: bool = true


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GAME)
	GameManager.back_requested.connect(_on_back)
	_load_progress()
	# Geliştirme/prob: `-- --level=N` ile doğrudan o seviye açılır.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			_level_number = maxi(int(arg.split("=")[1]), 1)
			_persist = false
	_center_x = get_viewport_rect().size.x * 0.5
	_build_sky()
	_build_ui()
	_start_level()


func _process(delta: float) -> void:
	var target: float = 0.0
	if _board != null and _board.rack_slots() > 0:
		target = clampf(float(_board.rack_count()) / float(_board.rack_slots()), 0.0, 1.0)
		if _board.is_lost():
			target = 1.0
	_sky_weight = lerpf(_sky_weight, target * target, 1.0 - exp(-3.0 * delta))
	_sky_gradient.set_color(0, SKY_SUNNY_TOP.lerp(SKY_STORM_TOP, _sky_weight))
	_sky_gradient.set_color(1, SKY_SUNNY_BOTTOM.lerp(SKY_STORM_BOTTOM, _sky_weight))
	if _backdrop != null:
		_backdrop.storm = _sky_weight
	# Tehlike: askıda tek boş slot kalınca askı kırmızı nabız atar.
	var near_full: bool = _board != null and not _board.is_over() \
		and _board.rack_count() >= _board.rack_slots() - 1
	_danger = (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)) if near_full else 0.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
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
	var first: String = String(events[0]["type"])
	if first != LaundryBoard.EVENT_BLOCKED and first != LaundryBoard.EVENT_LOCKED:
		Input.vibrate_handheld(12)
		AudioService.play_pitched("pin_click", randf_range(0.94, 1.08))
	_events.append_array(events)
	_refresh_open()
	_run_events()


func _refresh_open() -> void:
	for id: int in _views.keys():
		if _board.is_on_line(id):
			_views[id].set_open(_board.is_open(id))


func _run_events() -> void:
	if _playing:
		return
	_playing = true
	while not _events.is_empty():
		var event: Dictionary = _events.pop_front()
		await _play_event(event)
	_playing = false


func _play_event(event: Dictionary) -> void:
	match String(event["type"]):
		LaundryBoard.EVENT_BLOCKED:
			_views[int(event["id"])].wobble()
			for blocker: Variant in event["by"] as Array:
				_views[int(blocker)].flash()
		LaundryBoard.EVENT_LOCKED:
			_views[int(event["id"])].wobble()
			# Hangi sepetin beklendiğini göster: o renkteki aktif sepet zıplar.
			for basket: BasketView in _baskets:
				if basket.visible and basket.color.is_equal_approx(COLORS[int(event["color"]) % COLORS.size()]):
					var hop: Tween = basket.create_tween()
					hop.tween_property(basket, "scale", Vector2.ONE * 1.12, 0.1)
					hop.tween_property(basket, "scale", Vector2.ONE, 0.14)
		LaundryBoard.EVENT_WRING:
			_views[int(event["id"])].wring()
			AudioService.play_pitched("wring", randf_range(0.95, 1.05))
		LaundryBoard.EVENT_UNLOCK:
			_views[int(event["id"])].unlock()
			AudioService.play_pitched("unlock", 1.0, -4.0)
		LaundryBoard.EVENT_TO_RACK:
			var view: GarmentView = _views[int(event["id"])]
			AudioService.play_pitched("cloth", randf_range(0.9, 1.1), -6.0)
			_fly(view, _rack_points[int(event["slot"])], RACK_GARMENT_SCALE)
			await get_tree().create_timer(FLIGHT_STAGGER).timeout
		LaundryBoard.EVENT_TO_BASKET, LaundryBoard.EVENT_RACK_TO_BASKET:
			var index: int = int(event["basket"])
			var flying: GarmentView = _views[int(event["id"])]
			_basket_items[index].append(flying)
			AudioService.play_pitched("cloth", randf_range(0.9, 1.1), -6.0)
			# Sepete giderken havada katlanır; sepette katlar üst üste ayrı ayrı durur.
			flying.z_index = 60 + int(event["index"])
			_fly(flying, _baskets[index].slot_position(int(event["index"])), 1.0)
			flying.fold(FLIGHT_SECONDS, _baskets[index].folded_width())
			# Katlar birbirinden ayrışsın: her kat hafif döner ve biraz farklı tonda durur.
			var stack_index: int = int(event["index"])
			flying.create_tween().tween_property(flying, "rotation_degrees",
				STACK_TILT_DEGREES * (1.0 if stack_index % 2 == 0 else -1.0), FLIGHT_SECONDS)
			flying.modulate = Color.WHITE.darkened(STACK_SHADE * float(2 - stack_index))
			_baskets[index].set_filled(int(event["index"]) + 1)
			await get_tree().create_timer(FLIGHT_STAGGER).timeout
		LaundryBoard.EVENT_BASKET_DONE:
			await _fold_basket(int(event["basket"]))
		LaundryBoard.EVENT_BASKET_NEW:
			_bring_basket(int(event["basket"]), int(event["color"]))
		LaundryBoard.EVENT_WIN:
			await get_tree().create_timer(FLIGHT_SECONDS).timeout
			_show_win()
		LaundryBoard.EVENT_LOSE:
			Input.vibrate_handheld(300)
			AudioService.play_pitched("wind", 1.0, -3.0)
			await get_tree().create_timer(FLIGHT_SECONDS + 0.2).timeout
			_show_lose(int(event.get("remaining", 0)))


## Yay çizerek uçuş (0,28 sn). Mandallar ipte kalır gibi kaybolur.
func _fly(view: GarmentView, target: Vector2, target_scale: float) -> void:
	view.detach_pins()
	view.set_open(true)
	view.z_index = maxi(view.z_index, 50)
	var start: Vector2 = view.global_position
	var tween: Tween = view.create_tween().set_parallel(true)
	tween.tween_method(func(weight: float) -> void:
		view.global_position = start.lerp(target, weight) \
			+ Vector2(0.0, -FLIGHT_ARC * sin(PI * weight)), 0.0, 1.0, FLIGHT_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(view, "scale", Vector2.ONE * target_scale, FLIGHT_SECONDS)


## Sepet doldu: çamaşırlar katlanıp kaybolur, sepet aşağı kayar.
func _fold_basket(index: int) -> void:
	await get_tree().create_timer(FLIGHT_SECONDS).timeout
	Input.vibrate_handheld(40)
	var now: int = Time.get_ticks_msec()
	_combo = _combo + 1 if now - _last_fold_msec < int(COMBO_RESET_SECONDS * 1000.0) else 0
	_last_fold_msec = now
	AudioService.play_pitched("fold_puff", randf_range(0.96, 1.04))
	AudioService.play_pitched("note", pow(COMBO_SEMITONE, float(mini(_combo, COMBO_MAX_STEPS)) * 2.0), -5.0)
	var basket: BasketView = _baskets[index]
	_sparkle(basket.global_position + Vector2(0.0, -BASKET_SIZE * 0.3), basket.color)
	var tween: Tween = create_tween().set_parallel(true)
	for garment: Variant in _basket_items[index]:
		var view: GarmentView = garment as GarmentView
		# Yığın sepetin içine çöker.
		tween.tween_property(view, "global_position", basket.global_position + Vector2(0.0, -BASKET_SIZE * 0.08), FOLD_SECONDS * 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(view, "scale", Vector2(0.75, 0.3), FOLD_SECONDS * 0.5)
		tween.tween_property(view, "modulate:a", 0.0, FOLD_SECONDS * 0.2).set_delay(FOLD_SECONDS * 0.35)
	tween.tween_property(basket, "scale", Vector2(1.12, 0.9), FOLD_SECONDS * 0.3)
	tween.chain().tween_property(basket, "scale", Vector2.ONE, FOLD_SECONDS * 0.2)
	tween.chain().tween_property(basket, "position:y", BASKET_Y + BASKET_SLIDE, FOLD_SECONDS * 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	for garment: Variant in _basket_items[index]:
		(garment as GarmentView).queue_free()
	_basket_items[index].clear()
	basket.visible = false
	basket.set_filled(0)
	queue_redraw()


## Sepet tamamlanınca yumuşak parıltı patlaması (sepet renginde + sıcak beyaz).
func _sparkle(at: Vector2, tint: Color) -> void:
	for layer_color: Color in [SPARKLE_COLOR, tint.lightened(0.35)]:
		var burst: CPUParticles2D = CPUParticles2D.new()
		burst.one_shot = true
		burst.explosiveness = 0.92
		burst.amount = 16
		burst.lifetime = 0.75
		burst.texture = GarmentView.circle_texture()
		burst.direction = Vector2.UP
		burst.spread = 75.0
		burst.gravity = Vector2(0.0, 260.0)
		burst.initial_velocity_min = 160.0
		burst.initial_velocity_max = 380.0
		burst.scale_amount_min = 0.06
		burst.scale_amount_max = 0.16
		burst.color = layer_color
		burst.z_index = 90
		burst.global_position = at
		_world.add_child(burst)
		burst.emitting = true
		get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


func _bring_basket(index: int, color_index: int) -> void:
	var basket: BasketView = _baskets[index]
	basket.set_color(COLORS[color_index % COLORS.size()])
	basket.position.y = BASKET_Y + BASKET_SLIDE
	var tween: Tween = create_tween()
	tween.tween_property(basket, "position:y", BASKET_Y, FOLD_SECONDS * 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _start_level() -> void:
	if _world != null:
		_world.queue_free()
	_hide_overlay()
	_events.clear()
	_views.clear()
	_baskets.clear()
	_basket_items.clear()
	_rack_points.clear()
	_line_ys.clear()
	_revived = false
	_combo = 0
	_level = LevelGenerator.generate(_level_number)
	_board = LaundryBoard.new(_level)
	_level_label.text = "Seviye %d" % _level_number
	_world = Node2D.new()
	add_child(_world)
	_build_lines()
	_build_rack()
	_build_baskets()
	_refresh_open()
	queue_redraw()


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
		_world.add_child(view)
		_views[int(item["id"])] = view
		if bool(item.get("wet", false)):
			view.set_wet(true)
		if bool(item.get("mystery", false)):
			view.set_mystery(true)
		if item.has("lock"):
			view.set_lock(COLORS[int(item["lock"]) % COLORS.size()])


func _build_rack() -> void:
	var slots: int = _board.rack_slots()
	for slot: int in range(slots):
		_rack_points.append(Vector2(
			_center_x + (float(slot) - float(slots - 1) * 0.5) * RACK_SPACING, RACK_Y))


func _build_baskets() -> void:
	var states: Array[Dictionary] = _board.baskets()
	for index: int in range(states.size()):
		var basket: BasketView = BasketView.new()
		basket.setup(BASKET_SIZE)
		basket.position = Vector2(
			_center_x + (float(index) - float(states.size() - 1) * 0.5) * BASKET_SPACING, BASKET_Y)
		_world.add_child(basket)
		_baskets.append(basket)
		_basket_items.append([])
		if states[index].is_empty():
			basket.visible = false
		else:
			basket.set_color(COLORS[int(states[index]["color"]) % COLORS.size()])


func _draw() -> void:
	if _board == null:
		return
	var width: float = get_viewport_rect().size.x
	# İpler: hafif sarkan çizgi.
	for y: float in _line_ys:
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in range(25):
			var t: float = float(step) / 24.0
			points.append(Vector2(lerpf(34.0, width - 34.0, t), y - 6.0 + 10.0 * sin(PI * t)))
		draw_polyline(points, ROPE_COLOR, 5.0, true)
	# Bekleme askısı: çubuk + slot işaretleri.
	if not _rack_points.is_empty():
		var bar_color: Color = RACK_COLOR.lerp(DANGER_COLOR, _danger)
		var left: Vector2 = _rack_points[0] + Vector2(-RACK_SPACING * 0.5, -14.0)
		var right: Vector2 = _rack_points[_rack_points.size() - 1] + Vector2(RACK_SPACING * 0.5, -14.0)
		draw_line(left, right, bar_color, 12.0, true)
		draw_circle(left, 6.0, bar_color, true, -1.0, true)
		draw_circle(right, 6.0, bar_color, true, -1.0, true)
		for point: Vector2 in _rack_points:
			draw_circle(point + Vector2(0.0, 44.0), 46.0, Color(0.0, 0.0, 0.0, 0.07), true, -1.0, true)
	# Sıradaki sepetler: küçük renk noktaları (soldan sağa sıra).
	var queue: Array[int] = _board.queue()
	var shown: int = mini(queue.size(), QUEUE_SHOWN)
	for index: int in range(shown):
		var center: Vector2 = Vector2(
			_center_x + (float(index) - float(shown - 1) * 0.5) * QUEUE_DOT * 3.0, QUEUE_Y)
		var radius: float = QUEUE_DOT * (1.0 if index == 0 else 0.72)
		draw_circle(center, radius, COLORS[queue[index] % COLORS.size()], true, -1.0, true)


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
	_backdrop.setup(get_viewport_rect().size)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_level_label = Label.new()
	_level_label.position = Vector2(_center_x - 200.0, 90.0)
	_level_label.custom_minimum_size = Vector2(400.0, 0.0)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 40)
	_level_label.add_theme_color_override("font_color", TEXT_COLOR)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_level_label)
	var restart: Button = _flat_button("↻", false)
	restart.position = Vector2(get_viewport_rect().size.x - 130.0, 80.0)
	restart.custom_minimum_size = Vector2(84.0, 84.0)
	restart.pressed.connect(_start_level)
	_ui.add_child(restart)


## Düz, çizgisiz düğme (kullanıcı tercihi: minimal modern arayüz).
func _flat_button(text: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
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
	_overlay.add_child(panel)
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
	panel.pivot_offset = panel.size * 0.5
	Juice.pop_in(panel)


func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _show_win() -> void:
	var reward: int = HARD_WIN_COINS if bool(_level.get("hard", false)) else WIN_COINS
	_coins += reward
	_level_number += 1
	_save_progress()
	AudioService.play_pitched("win", 1.0, -3.0)
	var next: Button = _flat_button("Devam", true)
	next.pressed.connect(_start_level)
	_show_overlay("Harika!", "+%d jeton" % reward, [next])


func _show_lose(remaining: int) -> void:
	var buttons: Array[Button] = []
	if not _revived:
		var revive: Button = _flat_button("Reklam izle, +1 askı", true)
		revive.pressed.connect(_revive)
		buttons.append(revive)
	var retry: Button = _flat_button("Tekrar dene", _revived)
	retry.pressed.connect(_start_level)
	buttons.append(retry)
	var subtitle: String = "Sadece %d çamaşır kaldı" % remaining if remaining <= 6 \
		else "%d çamaşır kaldı" % remaining
	_show_overlay("Fırtına çıktı", subtitle, buttons)


## Prototip: reklam henüz bağlı değil; ödül doğrudan verilir (seviye başına 1 kez).
func _revive() -> void:
	_revived = true
	_board.add_rack_slot()
	_rack_points.clear()
	_build_rack()
	var rack: Array[int] = _board.rack()
	for slot: int in range(rack.size()):
		if rack[slot] != LaundryBoard.EMPTY:
			_views[rack[slot]].global_position = _rack_points[slot]
	_hide_overlay()


func _on_back() -> void:
	GameManager.goto_scene(&"menu")


func _load_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	_level_number = maxi(int(config.get_value("progress", "level", 1)), 1)
	_coins = maxi(int(config.get_value("progress", "coins", 0)), 0)


func _save_progress() -> void:
	if not _persist:
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "level", _level_number)
	config.set_value("progress", "coins", _coins)
	config.save(SAVE_PATH)
