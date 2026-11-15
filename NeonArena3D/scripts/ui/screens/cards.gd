extends MenuScreen
## Seviye atlama kart seçimi: 3 kart (1/2/3 tuşları), YENİLE (reroll) düğmesi.
##
## EKLENECEK YER (reklam görevi C8): yenileme hakkı bitince "REKLAM İZLE -> +1 YENİLE" düğmesi.
##  * `reroll_button`: mevcut YENİLE düğmesi (metni/görünürlüğü `show_cards` her açılışta ayarlar).
##  * `add_below_reroll(düğme)`: ek düğmeyi YENİLE'nin altına koyar; görünürlüğünü `Ads.can_show(REROLL)` belirler.

const KIT = preload("res://scripts/ui/ui_kit.gd")
const W = preload("res://scripts/ui/screens/widgets.gd")

var box: VBoxContainer
var reroll_button: Button
var _title: Label
var _row: HBoxContainer
var _buttons: Array = []


func build() -> void:
	root = host.make_screen("cards", 0.8)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	host.center(root).add_child(box)
	_title = KIT.heading(tr("SEVİYE ATLADIN"), 46, KIT.GOLD)
	box.add_child(_title)
	box.add_child(KIT.label(tr("bir yükseltme seç"), 18, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(KIT.spacer(10))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 30)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_row)
	box.add_child(KIT.spacer(12))
	reroll_button = KIT.button(tr("YENİLE"), KIT.GOLD, Vector2(250, 52), 19)
	reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll_button.pressed.connect(func(): host.reroll_pressed.emit())
	box.add_child(reroll_button)


func card_count() -> int:
	return _buttons.size()


func present(cards: Array, level: int, rerolls: int, counts: Dictionary) -> void:
	for child in _row.get_children():
		child.queue_free()
	_buttons.clear()
	_title.text = tr("SEVİYE %d") % level
	for i in cards.size():
		var card: Dictionary = cards[i]
		var b := W.CardButton.new()
		b.card = card
		b.owned = int(counts.get(str(card.get("id", "")), 0))
		b.key_hint = "" if Settings.touch else str(i + 1)
		var index := i
		b.pressed.connect(func(): host.card_picked.emit(index))
		if not Settings.touch:
			b.mouse_entered.connect(func(): Sound.play("ui_hover"))
		_row.add_child(b)
		_buttons.append(b)
		b.modulate.a = 0.0
		b.disabled = true
		var tw := b.create_tween()
		tw.tween_interval(0.07 * float(i))
		tw.tween_property(b, "modulate:a", 1.0, 0.22)
		tw.tween_interval(0.12)
		tw.tween_callback(func(): b.disabled = false)
	reroll_button.text = tr("YENİLE  (%d)") % rerolls
	reroll_button.disabled = rerolls <= 0
	reroll_button.visible = true
	host.show_screen("cards")


## SEAM: YENİLE düğmesinin altına ek denetim (reklamla +1 yenileme vb.) ekler.
func add_below_reroll(control: Control) -> void:
	box.add_child(control)
	box.move_child(control, reroll_button.get_index() + 1)
