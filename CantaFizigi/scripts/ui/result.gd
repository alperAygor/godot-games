extends Control

## Sonuc ekrani: GameManager.last_result sozlugunu gosterir.
## {damage, stars, multiplier, fee, reputation, success, placed, report[]}

@onready var title_label: Label = %Title
@onready var stars_label: Label = %Stars
@onready var detail_label: Label = %Detail
@onready var report_box: VBoxContainer = %Report


func _ready() -> void:
	var result: Dictionary = GameManager.last_result
	var stars: int = int(result.get("stars", 0))
	var fee: int = int(result.get("fee", 0))
	var damage: float = float(result.get("damage", 0.0))

	title_label.text = "Teslimat Tamamlandı" if stars > 0 else "Teslimat Hasarlı"
	stars_label.text = "Yıldız: %d / 3" % stars
	detail_label.text = "Hasar: %%%d    Ücret: %d" % [int(roundf(damage * 100.0)), fee]
	_fill_report(result.get("report", []))

	(%RetryButton as Button).pressed.connect(_on_retry)
	(%MenuButton as Button).pressed.connect(_on_menu)
	GameManager.back_requested.connect(_on_menu)

	if stars > 0:
		AudioService.play_success()


func _fill_report(entries: Variant) -> void:
	if not (entries is Array):
		return
	var rows: Array = entries
	if rows.is_empty():
		return
	for entry: Variant in rows:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var line: Label = Label.new()
		line.text = "%s — %%%d hasar" % [String(row.get("label", "?")),
			int(roundf(float(row.get("damage", 0.0)) * 100.0))]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", 26)
		line.add_theme_color_override("font_color", Color(0.478, 0.416, 0.369, 1.0))
		report_box.add_child(line)


func _on_retry() -> void:
	GameManager.goto_scene(&"game")


func _on_menu() -> void:
	GameManager.goto_scene(&"menu")
