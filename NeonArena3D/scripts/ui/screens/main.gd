extends MenuScreen
## Ana menü: başlık, OYNA / HANGAR / ATÖLYE / NASIL OYNANIR / AYARLAR / ÇIKIŞ, rekor paneli, çekirdek rozeti, duyuru şeridi.
##
## EKLENECEK YERLER (sonraki görevler):
##  * Günlük meydan okuma / görevler / başarımlar / mağaza (reklamsız satın alma) girişleri -> `add_entry(düğme)`.
##    Düğme `KIT.button(...)` ile aynı ölçüde (Vector2(360, 54)) üretilir; `entries_column` OYNA'dan ÇIKIŞ'a kadar tek dikey sütundur.
##  * Günlük reklam bonusu girişi (`Ads.daily_bonus_available()`) de aynı yolla eklenir.

const KIT = preload("res://scripts/ui/ui_kit.gd")
const W = preload("res://scripts/ui/screens/widgets.gd")
const VERSION := "v1.2"

var column: VBoxContainer
var cores: W.CoreBadge
var quit_button: Button
var _stat_labels: Dictionary = {}
var _notice: Label


func build() -> void:
	root = host.make_screen("main", 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(host.side_shade(0.92))
	var margin: Vector4 = host.margin

	column = VBoxContainer.new()
	column.anchor_top = 0.0
	column.anchor_bottom = 1.0
	column.offset_left = margin.x + 56.0
	column.offset_right = margin.x + 616.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)
	column.add_child(W.TitleArt.new())
	column.add_child(KIT.label(tr("hayatta kal  ·  güçlen  ·  sektörleri temizle"), 17, KIT.DIM))
	column.add_child(KIT.spacer(14))
	var play := KIT.button(tr("OYNA"), KIT.CYAN, Vector2(360, 78), 32, true)
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play.pressed.connect(func(): host.play_pressed.emit())
	column.add_child(play)
	host.focus["main"] = play
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var hangar := KIT.button(tr("HANGAR"), KIT.GREEN, Vector2(174, 58), 20)
	hangar.pressed.connect(func(): host.open_sub("hangar", "main"))
	row.add_child(hangar)
	var shop := KIT.button(tr("ATÖLYE"), KIT.GOLD, Vector2(174, 58), 20)
	shop.pressed.connect(func(): host.open_sub("workshop", "main"))
	row.add_child(shop)
	column.add_child(row)
	var how := KIT.button(tr("NASIL OYNANIR"), KIT.VIOLET, Vector2(360, 54), 20)
	how.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	how.pressed.connect(func(): host.open_sub("howto", "main"))
	column.add_child(how)
	var settings := KIT.button(tr("AYARLAR"), KIT.VIOLET, Vector2(360, 54), 20)
	settings.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	settings.pressed.connect(func(): host.open_sub("settings", "main"))
	column.add_child(settings)
	if not OS.has_feature("mobile"):
		quit_button = KIT.button(tr("ÇIKIŞ"), Color(0.6, 0.66, 0.78), Vector2(360, 48), 18)
		quit_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		quit_button.pressed.connect(func(): host.get_tree().quit())
		column.add_child(quit_button)

	var stats := KIT.panel(KIT.CYAN, 20.0)
	stats.anchor_left = 1.0
	stats.anchor_right = 1.0
	stats.anchor_top = 1.0
	stats.anchor_bottom = 1.0
	stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stats.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stats.offset_right = -margin.z - 28.0
	stats.offset_bottom = -margin.w - 28.0
	root.add_child(stats)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 6)
	stats.add_child(grid)
	for entry in [["best", tr("REKOR"), KIT.GOLD], ["best_wave", tr("EN İYİ DALGA"), KIT.CYAN], ["kills", tr("TOPLAM AVLANAN"), KIT.CYAN], ["runs", tr("KOŞU"), KIT.CYAN]]:
		grid.add_child(KIT.label(entry[1], 14, KIT.DIM))
		var value := KIT.label("0", 20, entry[2], KIT.bold(), HORIZONTAL_ALIGNMENT_RIGHT)
		value.custom_minimum_size = Vector2(110, 0)
		grid.add_child(value)
		_stat_labels[entry[0]] = value

	cores = W.CoreBadge.new(26)
	cores.anchor_left = 1.0
	cores.anchor_right = 1.0
	cores.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cores.offset_right = -margin.z - 30.0
	cores.offset_top = margin.y + 24.0
	root.add_child(cores)
	_notice = KIT.label("", 17, KIT.GOLD, KIT.bold(), HORIZONTAL_ALIGNMENT_RIGHT)
	_notice.anchor_left = 0.5
	_notice.anchor_right = 1.0
	_notice.offset_right = -margin.z - 30.0
	_notice.offset_top = margin.y + 66.0
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.modulate.a = 0.0
	root.add_child(_notice)

	var version := KIT.label(VERSION, 13, Color(KIT.DIM, 0.6))
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = margin.x + 58.0
	version.offset_top = -margin.w - 16.0
	root.add_child(version)


## Rekorları/çekirdeği tazeler, varsa hoş geldin bonusunu duyurur ve ekranı gösterir.
func present() -> void:
	(_stat_labels["best"] as Label).text = KIT.fmt(Settings.best)
	(_stat_labels["best_wave"] as Label).text = str(Settings.best_wave)
	(_stat_labels["kills"] as Label).text = KIT.fmt(Settings.total_kills)
	(_stat_labels["runs"] as Label).text = str(Settings.runs)
	cores.set_amount(Settings.meta.cores, false)
	var bonus := Settings.take_welcome()
	if bonus > 0:
		notify(tr("HOŞ GELDİN BONUSU: +%d ÇEKİRDEK — ATÖLYE'de harca") % bonus)
	host.show_screen("main")


func set_margins(m: Vector4) -> void:
	if column != null:
		column.offset_left = m.x + 56.0
		column.offset_right = m.x + 56.0 + 560.0


func notify(text: String, duration := 3.2) -> void:
	## Ana menü üstünde kısa duyuru (bonus, açılan gemi vb.).
	if _notice == null:
		return
	_notice.text = text
	var tw := _notice.create_tween()
	tw.tween_property(_notice, "modulate:a", 1.0, 0.25)
	tw.tween_interval(duration)
	tw.tween_property(_notice, "modulate:a", 0.0, 0.6)


## SEAM: ana sütuna yeni giriş ekler (günlük meydan okuma, görevler, başarımlar, mağaza/reklamsız...).
## `index` < 0 ise ÇIKIŞ düğmesinin (masaüstünde) hemen öncesine, yoksa sütunun sonuna konur.
func add_entry(entry: Control, index := -1) -> void:
	column.add_child(entry)
	if index >= 0:
		column.move_child(entry, mini(index, column.get_child_count() - 1))
	elif quit_button != null:
		column.move_child(entry, quit_button.get_index())
