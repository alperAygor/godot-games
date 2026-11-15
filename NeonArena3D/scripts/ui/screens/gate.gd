extends MenuScreen
## C1 sektör kapısı: iki sektör arasında kısa duraklama + 2–3 risk/ödül seçeneği (veri: waves.json → run.gates).
## Telefonda tek başparmakla: büyük kartlar ekranın alt yarısında, 1/2/3 tuşları, "ATLA" tek dokunuş. Süre baskısı yok;
## ilk kart her zaman güvenli (ONARIM) — çıkmaz yok. Seçim `chosen(id)` ("" = atla) ile RunFlow'a gider.
## Menü kaydı `menus.gd`'ye dokunmadan RunFlow tarafından yapılır (dil değişiminde `screens_rebuilt` ile yeniden).

signal chosen(option_id: String)

const KIT = preload("res://scripts/ui/ui_kit.gd")
const RISK_COLOR := [KIT.GREEN, KIT.VIOLET, KIT.RED]
const RISK_NAME := ["GÜVENLİ", "RİSKLİ", "TEHLİKELİ"]

var _title: Label
var _sub: Label
var _status: Label
var _row: HBoxContainer
var _skip: Button
var _cards: Array = []
var _locked := false


class GateCard extends BaseButton:
	## Kapı seçeneği kartı: risk şeridi, ad, artı (yeşil) / eksi (kırmızı) satırları.
	var title := ""
	var risk := 0
	var lines: Array = []       ## [[metin, olumlu mu], ...]
	var key_hint := ""
	var _hover := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(300, 300)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		var target := 1.0 if (is_hovered() or has_focus() or button_pressed) else 0.0
		_hover = lerpf(_hover, target, clampf(delta * 14.0, 0.0, 1.0))
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (1.0 + 0.04 * _hover - (0.03 if is_pressed() else 0.0))
		queue_redraw()

	func _draw() -> void:
		var c: Color = RISK_COLOR[clampi(risk, 0, RISK_COLOR.size() - 1)]
		var rect := Rect2(Vector2.ZERO, size)
		for i in 3:
			draw_rect(rect.grow(4.0 + float(i) * 5.0), Color(c, (0.05 + 0.09 * _hover) / float(i + 1)), true)
		draw_rect(rect, Color(0.025, 0.04, 0.085, 0.97), true)
		draw_rect(Rect2(0, 0, size.x, 86), Color(c.r * 0.14, c.g * 0.14, c.b * 0.14, 0.9), true)
		draw_rect(rect, Color(c, 0.6 + 0.4 * _hover), false, 2.0 + 1.5 * _hover)
		draw_rect(Rect2(0, 0, size.x, 6), c, true)
		draw_string(KIT.bold(), Vector2(0, 32), tr(RISK_NAME[clampi(risk, 0, RISK_NAME.size() - 1)]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(c, 0.95))
		draw_string(KIT.title(), Vector2(8, 68), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 24, Color(1, 1, 1))
		var y := 124.0
		for line in lines:
			var good := bool(line[1])
			var lc := KIT.GREEN if good else KIT.RED
			draw_string(KIT.bold(), Vector2(22, y), "+" if good else "−", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, lc)
			var text := str(line[0])
			draw_multiline_string(KIT.font(), Vector2(46, y), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 64, 18, 3, Color(0.86, 0.93, 1.0))
			var h := KIT.font().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 64, 18, 3).y
			y += maxf(24.0, h) + 20.0
		if key_hint != "":
			draw_rect(Rect2(14, size.y - 44, 30, 30), Color(c, 0.18), true)
			draw_rect(Rect2(14, size.y - 44, 30, 30), Color(c, 0.8), false, 1.5)
			draw_string(KIT.bold(), Vector2(14, size.y - 22), key_hint, HORIZONTAL_ALIGNMENT_CENTER, 30, 17, Color(1, 1, 1))


func build() -> void:
	root = host.make_screen("gate", 0.78)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -host.margin.w - 26.0
	box.offset_top = host.margin.y + 30.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_title = KIT.heading(tr("SEKTÖR TEMİZ"), 48, KIT.GOLD)
	box.add_child(_title)
	_sub = KIT.label("", 18, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_sub)
	box.add_child(KIT.spacer(8))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 24)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_row)
	box.add_child(KIT.spacer(6))
	_status = KIT.label("", 16, KIT.GOLD, KIT.bold(), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	_skip = KIT.button(tr("ATLA"), Color(0.6, 0.66, 0.78), Vector2(220, 52), 18)
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip.pressed.connect(func(): _pick(""))
	box.add_child(_skip)


func card_count() -> int:
	return _cards.size()


## options: [{id, name, risk, lines}] (RunFlow çözer; lanetli kart C3 tanımlıysa onun adı/etkisi).
## info: {cleared, total, next_name, reward_mult, banked}
func present(options: Array, info: Dictionary) -> void:
	for child in _row.get_children():
		child.queue_free()
	_cards.clear()
	_locked = false
	_title.text = tr("SEKTÖR %d / %d TEMİZ") % [int(info.get("cleared", 1)), int(info.get("total", 3))]
	_sub.text = tr("bir yol seç  ·  sıradaki: %s") % tr(str(info.get("next_name", "")))
	var parts: Array = []
	if float(info.get("reward_mult", 1.0)) > 1.001:
		parts.append(tr("ödül ×%.2f") % float(info.get("reward_mult", 1.0)))
	if int(info.get("banked", 0)) > 0:
		parts.append(tr("kasada +%d çekirdek") % int(info.get("banked", 0)))
	_status.text = "  ·  ".join(PackedStringArray(parts))
	for i in options.size():
		var opt: Dictionary = options[i]
		var card := GateCard.new()
		card.title = str(opt.get("name", ""))
		card.risk = int(opt.get("risk", 0))
		card.lines = opt.get("lines", [])
		card.key_hint = "" if Settings.touch else str(i + 1)
		var id := str(opt.get("id", ""))
		card.pressed.connect(func(): _pick(id))
		_row.add_child(card)
		_cards.append(card)
		card.modulate.a = 0.0
		card.disabled = true
		var tw := card.create_tween()
		tw.tween_interval(0.06 * float(i))
		tw.tween_property(card, "modulate:a", 1.0, 0.2)
		tw.tween_callback(func(): card.disabled = false)
	if not _cards.is_empty():
		host.focus["gate"] = _cards[0]
	host.show_screen("gate")


func press(index: int) -> void:
	## 1/2/3 tuşu ya da araç: index'teki kartı seç (-1 = atla).
	if index < 0:
		_pick("")
	elif index < _cards.size() and not (_cards[index] as BaseButton).disabled:
		(_cards[index] as BaseButton).pressed.emit()


func _pick(id: String) -> void:
	if _locked:
		return   # çift dokunuş: ilk seçim geçerli
	_locked = true
	Sound.play("card_pick" if id != "" else "ui_back")
	chosen.emit(id)


## Saf: kapı tanımından (ve varsa C3 lanetli kartından) kart satırları üretir: [[metin, olumlu mu], ...].
## `curse` = Loadout.curse_info(kart) ({name, desc, drawback, reward_mult}); verilirse kartın etkisi (artı), bedeli (eksi)
## ve kartın KENDİ ödülü gösterilir — kapının yedek `effect`/`reward_mult`'u gösterilmez (oyun da onu uygulamaz).
static func describe(def: Dictionary, curse: Dictionary = {}) -> Array:
	var out: Array = []
	if def.has("heal_ratio"):
		out.append([TranslationServer.translate("can +%%%d") % int(round(float(def["heal_ratio"]) * 100.0)), true])
	if int(def.get("rerolls", 0)) > 0:
		out.append([TranslationServer.translate("+%d kart yenileme") % int(def["rerolls"]), true])
	if not curse.is_empty():
		out.append([TranslationServer.translate(str(curse.get("desc", ""))), true])
		if str(curse.get("drawback", "")) != "":
			out.append([TranslationServer.translate("bedel: %s") % TranslationServer.translate(str(curse["drawback"])), false])
		var rm := float(curse.get("reward_mult", 1.0))
		if rm > 1.0:
			out.append([TranslationServer.translate("koşu ödülü +%%%d") % int(round((rm - 1.0) * 100.0)), true])
	else:
		var effect: Dictionary = def.get("effect", {})
		if effect.has("damage_mult"):
			out.append([TranslationServer.translate("hasar +%%%d") % int(round(float(effect["damage_mult"]) * 100.0)), float(effect["damage_mult"]) > 0.0])
		if effect.has("max_hp_bonus"):
			out.append([TranslationServer.translate("azami can %+d") % int(effect["max_hp_bonus"]), float(effect["max_hp_bonus"]) > 0.0])
	if def.has("enemy_hp_mult"):
		out.append([TranslationServer.translate("sonraki sektörde düşman canı +%%%d") % int(round((float(def["enemy_hp_mult"]) - 1.0) * 100.0)), false])
	if def.has("enemy_damage_mult"):
		out.append([TranslationServer.translate("düşman hasarı +%%%d") % int(round((float(def["enemy_damage_mult"]) - 1.0) * 100.0)), false])
	if float(def.get("reward_mult", 0.0)) > 0.0 and curse.is_empty():
		out.append([TranslationServer.translate("koşu ödülü +%%%d") % int(round(float(def["reward_mult"]) * 100.0)), true])
	if int(def.get("bank_cores", 0)) > 0:
		out.append([TranslationServer.translate("+%d çekirdek hemen kasaya (ölsen de kalır)") % int(def["bank_cores"]), true])
		out.append([TranslationServer.translate("bu kapıda iyileşme yok"), false])
	return out
