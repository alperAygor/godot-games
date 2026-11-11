extends Control

## Bölüm seçimi (v0.2): sade 3x4 kart; sayı + 3 yıldız + kilit ikonu.
## İlerleme satırı, küçük geri butonu, dil değiştirici. Metinler Loc.t.
## Buton adları (Level1Button..Level12Button) QA sözleşmesidir — DEĞİŞTİRME.

const LEVEL_COUNT: int = 12
const STARS_PER_LEVEL: int = 3
const STAR_SIZE: int = 24
const AMBIENT_FADE: float = 1.2

@onready var grid: GridContainer = %Grid
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var back_button: Button = %BackButton
@onready var lang_button: Button = %LangButton

## Kart içerikleri: {"button": Button, "number": Label, "name": Label,
## "stars": Array[TextureRect], "lock": LockBadge}
var _cards: Array[Dictionary] = []


func _ready() -> void:
	_wire_buttons()
	_apply_icons()
	_build_cards()
	_refresh_texts()
	Loc.language_changed.connect(_on_language_changed)
	GameManager.back_requested.connect(_on_back)


func _wire_buttons() -> void:
	back_button.pressed.connect(_on_back)
	lang_button.pressed.connect(_on_lang_toggle)


func _apply_icons() -> void:
	back_button.expand_icon = true
	back_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Icons.apply(back_button, "lucide/arrow-left", UiKit.COLOR_TEXT, 40)
	lang_button.text = Loc.locale.to_upper()


func _build_cards() -> void:
	var profile: PlayerProfile = GameManager.profile
	_cards.clear()
	for index: int in range(1, LEVEL_COUNT + 1):
		var button: Button = grid.get_node_or_null("Level%dButton" % index) as Button
		if button == null:
			push_error("LevelSelect: Level%dButton bulunamadı" % index)
			continue
		_clear_children(button)
		button.text = ""
		var unlocked: bool = profile == null or profile.is_unlocked(index)
		button.disabled = not unlocked
		UiKit.apply_card_styles(button, unlocked)
		var card: Dictionary = _make_card(button, index, profile)
		_cards.append(card)
		button.pressed.connect(_on_level_pressed.bind(index))
		button.modulate.a = 1.0


func _make_card(button: Button, index: int, profile: PlayerProfile) -> Dictionary:
	var unlocked: bool = profile == null or profile.is_unlocked(index)
	var stars: int = 0 if profile == null else profile.stars(index)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14.0
	content.offset_top = 12.0
	content.offset_right = -14.0
	content.offset_bottom = -12.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var number: Label = UiKit.make_label("%02d" % index, 40,
		UiKit.COLOR_TEXT if unlocked else Color(UiKit.COLOR_MUTED.r, UiKit.COLOR_MUTED.g,
			UiKit.COLOR_MUTED.b, 0.85), true)
	number.name = "Number"
	content.add_child(number)

	var name_label: Label = UiKit.make_label("", 22,
		UiKit.COLOR_MUTED if unlocked else Color(UiKit.COLOR_MUTED.r, UiKit.COLOR_MUTED.g,
			UiKit.COLOR_MUTED.b, 0.75))
	name_label.name = "LevelName"
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	content.add_child(name_label)

	var stars_row: HBoxContainer = HBoxContainer.new()
	stars_row.name = "StarsRow"
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 6)
	stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stars_row)

	var star_views: Array[TextureRect] = []
	for star_index: int in STARS_PER_LEVEL:
		var star: TextureRect = UiKit.make_star(STAR_SIZE, star_index < stars)
		star.visible = unlocked
		stars_row.add_child(star)
		star_views.append(star)

	var lock: LockBadge = LockBadge.new()
	lock.name = "LockIcon"
	lock.visible = not unlocked
	lock.custom_minimum_size = Vector2(34.0, 34.0)
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(lock)
	stars_row.visible = unlocked

	return {
		"button": button,
		"number": number,
		"name": name_label,
		"stars": star_views,
		"lock": lock,
		"level": index,
	}


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _refresh_texts() -> void:
	title_label.text = Loc.t("levels.title")
	lang_button.text = Loc.locale.to_upper()
	var profile: PlayerProfile = GameManager.profile
	var total_stars: int = 0 if profile == null else profile.total_stars()
	subtitle_label.text = Loc.t("levels.progress", {
		"count": LEVEL_COUNT,
		"stars": total_stars,
		"total": LEVEL_COUNT * STARS_PER_LEVEL,
	})
	for card: Dictionary in _cards:
		var level: int = int(card.get("level", 0))
		var name_label: Label = card.get("name") as Label
		var number: Label = card.get("number") as Label
		if name_label != null:
			var unlocked: bool = profile == null or profile.is_unlocked(level)
			name_label.text = Loc.t("level.%d.name" % level)
			number.modulate.a = 1.0 if unlocked else 0.8
			var lock: LockBadge = card.get("lock") as LockBadge
			if lock != null:
				lock.visible = not unlocked


func _on_lang_toggle() -> void:
	UiKit.tap()
	Loc.toggle_locale()


func _on_language_changed(_locale: String) -> void:
	_refresh_texts()


func _on_level_pressed(level: int) -> void:
	UiKit.tap()
	GameManager.start_level(level)


func _on_back() -> void:
	UiKit.tap()
	GameManager.goto_menu()


# Kart girişinde alpha animasyonu YOK: ilk karede tüm 12 kart okunur olmalı
# (QA kare şikâyeti). Basış animasyonu ve yumuşak renk geçişleri yeterli.
