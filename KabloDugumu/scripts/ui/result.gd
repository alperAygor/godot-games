extends Control

## Sonuç ekranı: GameManager.last_result sözlüğünü ve profile rekorunu gösterir.
## last_result = LevelScoring.compute -> {stars, score, time_bonus, elapsed, shorts, peak}.
## Yıldızlar tek tek "pop" ile açılır; ses: AudioService.play("success").

const STAR_COUNT: int = 3
const STAR_POP_DELAY: float = 0.12
const COLOR_STAR_ON: Color = Color(1.000, 0.788, 0.290, 1.0)
const COLOR_STAR_OFF: Color = Color(0.220, 0.280, 0.330, 1.0)
const COLOR_ON_PRIMARY: Color = Color(0.012, 0.141, 0.125, 1.0)
const COLOR_ON_ACCENT: Color = Color(0.169, 0.129, 0.000, 1.0)

@onready var title_label: Label = %Title
@onready var stars_label: Label = %Stars
@onready var detail_label: Label = %Detail
@onready var score_label: Label = %Score
@onready var best_label: Label = %Best
@onready var star_row: HBoxContainer = %StarRow
@onready var next_button: Button = %NextButton
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	_wire_buttons()
	_wire_icons()
	var result: Dictionary = GameManager.last_result
	var stars: int = clampi(int(result.get("stars", 0)), 0, STAR_COUNT)
	var score: int = int(result.get("score", 0))
	var elapsed: float = maxf(float(result.get("elapsed", 0.0)), 0.0)
	var shorts: int = int(result.get("shorts", 0))
	var peak: float = clampf(float(result.get("peak", 0.0)), 0.0, 1.0)
	var time_bonus: int = int(result.get("time_bonus", 0))

	title_label.text = "BÖLÜM TAMAM" if stars > 0 else "BÖLÜM BİTTİ"
	stars_label.text = "%d / %d YILDIZ" % [stars, STAR_COUNT]
	detail_label.text = "Süre %s   ·   Kısa devre %d   ·   Tepe yük %%%d" \
		% [_format_time(elapsed), shorts, int(roundf(peak * 100.0))]
	score_label.text = "Puan %d   ·   Süre bonusu +%d" % [score, time_bonus]
	_fill_best(elapsed)
	next_button.visible = GameManager.has_next_level()
	AudioService.play("success")
	_prepare_stars()
	await get_tree().process_frame
	_animate_stars(stars)


func _wire_buttons() -> void:
	next_button.pressed.connect(_on_next)
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	GameManager.back_requested.connect(_on_menu)


func _wire_icons() -> void:
	next_button.expand_icon = true
	Icons.apply(next_button, "lucide/play", COLOR_ON_PRIMARY, 40)
	menu_button.expand_icon = true
	Icons.apply(menu_button, "lucide/arrow-left", COLOR_ON_ACCENT, 36)


func _fill_best(elapsed: float) -> void:
	var profile: PlayerProfile = GameManager.profile
	var best: float = 0.0 if profile == null else profile.best_time(GameManager.level_index)
	if best <= 0.0:
		best_label.text = "İlk tamamlama"
		return
	var is_record: bool = elapsed <= best + 0.01
	if is_record:
		best_label.text = "Yeni rekor · %s" % _format_time(best)
	else:
		best_label.text = "En iyi %s" % _format_time(best)


func _prepare_stars() -> void:
	for index: int in range(STAR_COUNT):
		var star: TextureRect = _star_at(index)
		if star == null:
			continue
		star.visible = true
		star.modulate = COLOR_STAR_OFF
		star.modulate.a = 0.0
		star.scale = Vector2.ONE


func _animate_stars(earned: int) -> void:
	for index: int in range(STAR_COUNT):
		var star: TextureRect = _star_at(index)
		if star == null:
			continue
		star.pivot_offset = star.size * 0.5
		var lit: bool = index < earned
		star.modulate = COLOR_STAR_ON if lit else COLOR_STAR_OFF
		star.modulate.a = 0.0
		star.scale = Vector2(0.25, 0.25) if lit else Vector2.ONE
		var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(STAR_POP_DELAY * float(index))
		tween.tween_property(star, "modulate:a", 1.0, 0.15)
		if lit:
			tween.parallel().tween_property(star, "scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _star_at(index: int) -> TextureRect:
	if index < 0 or index >= star_row.get_child_count():
		return null
	return star_row.get_child(index) as TextureRect


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(ceilf(seconds)))
	var minutes: int = floori(float(total) / 60.0)
	var rest: int = total - minutes * 60
	return "%02d:%02d" % [minutes, rest]


func _on_next() -> void:
	AudioService.play("ui_tap")
	GameManager.start_level(GameManager.level_index + 1)


func _on_retry() -> void:
	AudioService.play("ui_tap")
	GameManager.replay_level()


func _on_menu() -> void:
	AudioService.play("ui_tap")
	GameManager.goto_menu()
