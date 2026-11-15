extends MenuScreen
## C1 zafer ekranı: son sektörün boss'u yenilince. Koşunun özeti + bu anda bitirirsen kazanacağın çekirdek, iki seçenek:
##   SONUÇLAR        koşuyu bitir → oyun sonu ekranı "ZAFER" başlığıyla (×2 çekirdek teklifi ve geçiş reklamı kuralları aynı)
##   SONSUZA DEVAM   aynı koşu sınırsız sürer (MK-2 bosslar); ek ödül veride sınırlı (run.modes.<mod>.reward.extra_cap)
## Oyun duraklıdır; süre baskısı yok. Seçim `finish_pressed` / `continue_pressed` sinyalleriyle RunFlow'a gider.

signal finish_pressed
signal continue_pressed

const KIT = preload("res://scripts/ui/ui_kit.gd")
const W = preload("res://scripts/ui/screens/widgets.gd")

var _sub: Label
var _stats: Label
var _cores: W.CoreBadge
var _continue: Button
var _continue_note: Label
var _locked := false


func build() -> void:
	root = host.make_screen("victory", 0.7)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	host.center(root).add_child(box)
	box.add_child(KIT.heading(tr("ZAFER"), 76, KIT.GOLD))
	_sub = KIT.label("", 22, KIT.TEXT, KIT.bold(), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_sub)
	_stats = KIT.label("", 17, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_stats)
	box.add_child(KIT.spacer(6))
	var reward := HBoxContainer.new()
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	reward.add_theme_constant_override("separation", 14)
	_cores = W.CoreBadge.new(30)
	_cores.prefix = "+"
	reward.add_child(_cores)
	reward.add_child(KIT.label(tr("ÇEKİRDEK"), 16, KIT.DIM))
	box.add_child(reward)
	box.add_child(KIT.spacer(14))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	var finish := KIT.button(tr("SONUÇLAR"), KIT.CYAN, Vector2(300, 74), 26, true)
	finish.pressed.connect(func(): _press(true))
	row.add_child(finish)
	host.focus["victory"] = finish
	_continue = KIT.button(tr("SONSUZA DEVAM"), KIT.VIOLET, Vector2(300, 74), 22)
	_continue.pressed.connect(func(): _press(false))
	row.add_child(_continue)
	_continue_note = KIT.label("", 14, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_continue_note)


## info: {sectors, score, time, wave, cores (şimdi bitirince), can_continue, extra_cap}
func present(info: Dictionary) -> void:
	_locked = false
	_sub.text = tr("%d SEKTÖRÜN HEPSİ TEMİZLENDİ") % int(info.get("sectors", 3))
	_stats.text = tr("PUAN %s   ·   DALGA %d   ·   SÜRE %s") % [KIT.fmt(int(info.get("score", 0))), int(info.get("wave", 0)), KIT.fmt_time(float(info.get("time", 0.0)))]
	_cores.set_amount(0, false)
	_cores.set_amount(int(info.get("cores", 0)))
	var can := bool(info.get("can_continue", false))
	_continue.visible = can
	_continue_note.visible = can
	_continue_note.text = tr("sonsuza devam: aynı koşu sürer, bosslar güçlenir · en fazla +%d çekirdek daha") % int(info.get("extra_cap", 0))
	host.show_screen("victory")


func press(finish: bool) -> void:
	_press(finish)


func _press(finish: bool) -> void:
	if _locked:
		return
	_locked = true
	Sound.play("ui_click")
	if finish:
		finish_pressed.emit()
	else:
		continue_pressed.emit()
