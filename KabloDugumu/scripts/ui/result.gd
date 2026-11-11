extends Control

## Sonuç ekranı (v0.2): sade kart, yumuşak yıldız animasyonu, küçük butonlar.
## Veri: GameManager.last_result (LevelScoring.compute) + profile rekoru.
## İlk tamamlama kontrastı: "first clear" okunur renkte, yeni rekor amber.

const STAR_COUNT: int = 3
const STAR_POP_DELAY: float = 0.10
const STAR_POP_SECONDS: float = 0.45
const AMBIENT_FADE: float = 1.2

@onready var title_label: Label = %Title
@onready var star_row: HBoxContainer = %StarRow
@onready var stars_label: Label = %Stars
@onready var best_label: Label = %Best
@onready var score_label: Label = %Score
@onready var time_value: Label = %TimeValue
@onready var shorts_value: Label = %ShortsValue
@onready var peak_value: Label = %PeakValue
@onready var time_caption: Label = %TimeCaption
@onready var shorts_caption: Label = %ShortsCaption
@onready var peak_caption: Label = %PeakCaption
@onready var next_button: Button = %NextButton
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton

var _stars: int = 0
var _elapsed: float = 0.0
var _score: int = 0
var _bonus: int = 0


func _ready() -> void:
	_wire_buttons()
	_apply_icons()
	_read_result()
	_refresh_texts()
	_prepare_stars()
	_start_ambient()
	AudioService.play("success")
	Loc.language_changed.connect(_on_language_changed)
	GameManager.back_requested.connect(_on_menu)
	next_button.visible = GameManager.has_next_level()
	await get_tree().process_frame
	_animate_stars()


func _wire_buttons() -> void:
	next_button.pressed.connect(_on_next)
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)


func _apply_icons() -> void:
	next_button.expand_icon = true
	Icons.apply(next_button, "lucide/play", UiKit.COLOR_ON_PRIMARY, 38)
	retry_button.expand_icon = true
	Icons.apply(retry_button, "lucide/arrow-left", UiKit.COLOR_ON_ACCENT, 30)
	menu_button.expand_icon = true
	Icons.apply(menu_button, "lucide/arrow-left", UiKit.COLOR_TEXT, 32)


func _start_ambient() -> void:
	if AudioService.has_method(&"play_ambient"):
		AudioService.call(&"play_ambient", "ambient_pad", AMBIENT_FADE)


func _read_result() -> void:
	var result: Dictionary = GameManager.last_result
	_stars = clampi(int(result.get("stars", 0)), 0, STAR_COUNT)
	_elapsed = maxf(float(result.get("elapsed", 0.0)), 0.0)
	_score = int(result.get("score", 0))
	_bonus = int(result.get("time_bonus", 0))
	var shorts: int = int(result.get("shorts", 0))
	var peak: float = clampf(float(result.get("peak", 0.0)), 0.0, 1.0)
	time_value.text = _format_time(_elapsed)
	shorts_value.text = "%d" % shorts
	peak_value.text = "%%%d" % int(roundf(peak * 100.0))


func _refresh_texts() -> void:
	title_label.text = Loc.t("result.title")
	stars_label.text = Loc.t("result.stars", {"stars": _stars})
	time_caption.text = Loc.t("result.time_label")
	shorts_caption.text = Loc.t("result.shorts_label")
	peak_caption.text = Loc.t("result.peak_label")
	score_label.text = "%s  ·  %s" % [
		Loc.t("result.score", {"score": _score}),
		Loc.t("result.bonus", {"bonus": _bonus}),
	]
	next_button.text = Loc.t("result.next")
	retry_button.text = Loc.t("result.retry")
	menu_button.text = Loc.t("result.menu")
	_refresh_best()


## "İlk tamamlama" kontrastı: soluk gri yerine okunur gövde rengi + amber yeni rekor.
func _refresh_best() -> void:
	var profile: PlayerProfile = GameManager.profile
	var best: float = 0.0 if profile == null else profile.best_time(GameManager.level_index)
	if best <= 0.0:
		best_label.text = "%s  ·  %s" % [
			Loc.t("result.new_best"),
			_format_time(_elapsed),
		]
		best_label.add_theme_color_override("font_color", UiKit.COLOR_ACCENT)
		return
	var is_record: bool = _elapsed <= best + 0.01
	if is_record:
		best_label.text = "%s  ·  %s" % [
			Loc.t("result.new_best"),
			_format_time(best),
		]
		best_label.add_theme_color_override("font_color", UiKit.COLOR_ACCENT)
	else:
		best_label.text = Loc.t("result.best", {"time": _format_time(best)})
		best_label.add_theme_color_override("font_color", UiKit.COLOR_MUTED)


func _prepare_stars() -> void:
	for index: int in range(STAR_COUNT):
		var star: Control = _star_at(index)
		if star == null:
			continue
		star.visible = true
		if star.has_method(&"set_lit"):
			star.call(&"set_lit", index < _stars)
		star.modulate = Color.WHITE
		star.modulate.a = 0.0
		star.scale = Vector2(0.82, 0.82)


func _animate_stars() -> void:
	for index: int in range(STAR_COUNT):
		var star: Control = _star_at(index)
		if star == null:
			continue
		star.pivot_offset = star.size * 0.5
		var lit: bool = index < _stars
		if star.has_method(&"set_lit"):
			star.call(&"set_lit", lit)
		star.modulate = Color.WHITE
		star.modulate.a = 0.0
		star.scale = Vector2(0.82, 0.82) if lit else Vector2.ONE
		var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(STAR_POP_DELAY * float(index))
		tween.tween_property(star, "modulate:a", 1.0, STAR_POP_SECONDS * 0.5)
		if lit:
			tween.parallel().tween_property(star, "scale", Vector2.ONE, STAR_POP_SECONDS) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _star_at(index: int) -> Control:
	if index < 0 or index >= star_row.get_child_count():
		return null
	return star_row.get_child(index) as Control


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(ceilf(seconds)))
	var minutes: int = floori(float(total) / 60.0)
	var rest: int = total - minutes * 60
	return "%02d:%02d" % [minutes, rest]


func _on_language_changed(_locale: String) -> void:
	_refresh_texts()


func _on_next() -> void:
	UiKit.tap()
	GameManager.start_level(GameManager.level_index + 1)


func _on_retry() -> void:
	UiKit.tap()
	GameManager.replay_level()


func _on_menu() -> void:
	UiKit.tap()
	GameManager.goto_menu()
