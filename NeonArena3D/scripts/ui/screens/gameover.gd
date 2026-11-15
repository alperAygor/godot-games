extends MenuScreen
## Oyun sonu: sonuç, puan sayacı, istatistikler, çekirdek kazancı, kart şeridi, TEKRAR OYNA / ANA MENÜ.
##
## REKLAM (C8, MonetizationHooks bağlar):
##  * "İZLE: ÇEKİRDEKLER ×2" düğmesi -> `add_reward_action(düğme)`: çekirdek satırının hemen altına girer
##    (görünürlük `Ads.can_show(DOUBLE_CORES)`; ödül verilince `set_cores(...)` ile rozet güncellenir).
##  * Başka eylem düğmeleri (ör. paylaş, mağaza) -> `buttons_row` (TEKRAR OYNA / ANA MENÜ yanında).
## Geçiş reklamı bu ekranda GÖSTERİLMEZ; TEKRAR OYNA / ANA MENÜ sinyallerini dinleyen oyun kodu `Ads.maybe_interstitial` çağırır.

const KIT = preload("res://scripts/ui/ui_kit.gd")
const W = preload("res://scripts/ui/screens/widgets.gd")

var box: VBoxContainer
var buttons_row: HBoxContainer
var reward_row: HBoxContainer
var _title: Label
var _record: Label
var _score: Label
var _stats: Dictionary = {}
var _build: W.BuildStrip
var _target := 0
var _shown := 0.0
var _cores: W.CoreBadge
var _total: Label


func _stat_cell(grid: GridContainer, key: String, title: String) -> void:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(170, 0)
	cell.add_theme_constant_override("separation", 0)
	var value := KIT.label("0", 28, Color(1, 1, 1), KIT.bold(), HORIZONTAL_ALIGNMENT_CENTER)
	cell.add_child(value)
	cell.add_child(KIT.label(title, 13, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER))
	grid.add_child(cell)
	_stats[key] = value


func build() -> void:
	root = host.make_screen("gameover", 0.74)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	host.center(root).add_child(box)
	_title = KIT.heading(tr("OYUN BİTTİ"), 62, KIT.RED)
	box.add_child(_title)
	_record = KIT.label("", 20, KIT.GOLD, KIT.bold(), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_record)
	_score = KIT.label("0", 68, Color(1, 1, 1), KIT.title(), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_score)
	box.add_child(KIT.label(tr("PUAN"), 14, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(KIT.spacer(8))
	var panel := KIT.panel(KIT.RED, 18.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	panel.add_child(grid)
	_stat_cell(grid, "wave", tr("DALGA"))
	_stat_cell(grid, "level", tr("SEVİYE"))
	_stat_cell(grid, "kills", tr("AVLANAN"))
	_stat_cell(grid, "combo", tr("EN İYİ KOMBO"))
	_stat_cell(grid, "time", tr("SÜRE"))
	reward_row = HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 18)
	_cores = W.CoreBadge.new(26)
	_cores.prefix = "+"
	reward_row.add_child(_cores)
	_total = KIT.label("", 16, KIT.DIM)
	_total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(_total)
	box.add_child(KIT.spacer(2))
	box.add_child(reward_row)
	_build = W.BuildStrip.new()
	_build.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_build)
	box.add_child(KIT.spacer(10))
	buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 22)
	box.add_child(buttons_row)
	var again := KIT.button(tr("TEKRAR OYNA"), KIT.CYAN, Vector2(320, 70), 26, true)
	again.pressed.connect(func(): host.restart_pressed.emit())
	buttons_row.add_child(again)
	host.focus["gameover"] = again
	var menu := KIT.button(tr("ANA MENÜ"), Color(0.6, 0.66, 0.78), Vector2(240, 70), 22)
	menu.pressed.connect(func(): host.menu_pressed.emit())
	buttons_row.add_child(menu)


func present(stats: Dictionary, build_items: Array) -> void:
	var record := bool(stats.get("record", false))
	_record.text = tr("YENİ REKOR!") if record else tr("REKOR  %s") % KIT.fmt(int(stats.get("best", 0)))
	_record.add_theme_color_override("font_color", KIT.GOLD if record else KIT.DIM)
	_target = int(stats.get("score", 0))
	_shown = 0.0
	(_stats["wave"] as Label).text = str(int(stats.get("wave", 1)))
	(_stats["level"] as Label).text = str(int(stats.get("level", 1)))
	(_stats["kills"] as Label).text = KIT.fmt(int(stats.get("kills", 0)))
	(_stats["combo"] as Label).text = str(int(stats.get("combo", 0)))
	(_stats["time"] as Label).text = KIT.fmt_time(float(stats.get("time", 0.0)))
	_cores.set_amount(0, false)
	_cores.set_amount(int(stats.get("cores", 0)))
	_total.text = tr("ÇEKİRDEK KAZANDIN  ·  toplam %s") % KIT.fmt(int(stats.get("total_cores", 0)))
	_build.set_items(build_items)
	host.show_screen("gameover")


## Puan sayacı animasyonu (Menus._process çağırır).
func tick(delta: float) -> void:
	if _score == null:
		return
	_shown = lerpf(_shown, float(_target), clampf(delta * 3.5, 0.0, 1.0))
	if absf(_shown - float(_target)) < 1.0:
		_shown = float(_target)
	_score.text = KIT.fmt(int(round(_shown)))


## C1: başlık (ZAFER / OYUN BİTTİ). RunFlow her `show_gameover` sonrası çağırır.
func set_title(text: String, color: Color) -> void:
	_title.text = text
	_title.add_theme_color_override("font_color", color)
	_title.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, 0.22))


## Çekirdek kazancı rozetini ve toplamı günceller (çift çekirdek ödülü sonrası).
func set_cores(earned: int, total: int) -> void:
	_cores.set_amount(earned)
	_total.text = tr("ÇEKİRDEK KAZANDIN  ·  toplam %s") % KIT.fmt(total)


## SEAM: çekirdek kazancı satırının hemen altına eylem (ör. "İZLE: ×2") ekler.
func add_reward_action(control: Control) -> void:
	box.add_child(control)
	box.move_child(control, reward_row.get_index() + 1)
