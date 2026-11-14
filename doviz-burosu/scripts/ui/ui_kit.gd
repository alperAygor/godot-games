class_name UiKit
extends RefCounted
## Kodla kurulan ekranların ortak yardımcıları (etiket/buton/kart üretimi, para ve dil).


## Stil A "Kâğıt Ofis" renkleri (tema paleti ile aynı; temada olmayan, kodda çizilen yerler için).
const DIM_COLOR := Color(0.102, 0.09, 0.07, 0.55)
const GOOD_COLOR := Color(0.345, 0.478, 0.231)
const WARN_COLOR := Color(0.62, 0.47, 0.13)
const BAD_COLOR := Color(0.66, 0.23, 0.17)
const INK_COLOR := Color(0.145, 0.133, 0.102)


static func label(text: String, variation := &"", node_name := "") -> Label:
	var node := Label.new()
	node.text = text
	if variation != &"":
		node.theme_type_variation = variation
	if not node_name.is_empty():
		node.name = node_name
	return node


static func wrapped(text: String, variation := &"", node_name := "") -> Label:
	var node := label(text, variation, node_name)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func button(text: String, node_name: String, variation := &"", min_height := 0.0) -> Button:
	var node := Button.new()
	node.text = text
	node.name = node_name
	if variation != &"":
		node.theme_type_variation = variation
	if min_height > 0.0:
		node.custom_minimum_size.y = min_height
	return node


## Küçük ikonlu düğme. `inline`: ikon solda, metin sağda (geri, paylaş, reklam); değilse ikon üstte, etiket altta.
## `text` tam metin olarak durur (testler/erişilebilirlik); ekranda `short_label` (varsa) çizilir. `dark`: koyu zeminde açık renk.
static func icon_button(icon_name: String, text: String, node_name: String, inline := true, dark := false, min_height := 76.0, short_label := "") -> IconButton:
	var button := IconButton.new()
	button.glyph = icon_name
	button.text = text
	button.label_text = short_label
	button.name = node_name
	button.inline_layout = inline
	button.light_on_dark = dark
	button.custom_minimum_size.y = min_height
	return button


## Talimat metni ("Bugün en az 13 müşteriye hizmet verin.").
static func directive_text(def: Dictionary) -> String:
	return TranslationServer.translate("DIR_%s" % str(def["id"]).to_upper()) % int(def["value"])


## Talimatın şartları: "Yerine getirilirse: +60 PL" ve (varsa) "Aksi halde: -30 PL".
static func directive_terms(def: Dictionary) -> Array[String]:
	var lines: Array[String] = [TranslationServer.translate("DIR_REWARD") % money(Money.units(int(def["reward_pl"])), "PL")]
	if int(def["penalty_pl"]) > 0:
		lines.append(TranslationServer.translate("DIR_PENALTY") % money(Money.units(int(def["penalty_pl"])), "PL"))
	else:
		lines.append(TranslationServer.translate("DIR_NO_PENALTY"))
	return lines


## Başlıklı kart: dönen VBox'a içerik eklenir. `card_variation`: CardPanel, FloatCard... `icon_name`: başlığın solunda küçük ikon.
static func card(title: String, card_variation := &"CardPanel", node_name := "", icon_name := "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = card_variation
	if not node_name.is_empty():
		panel.name = node_name
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	if not title.is_empty():
		var heading := label(title, &"CardTitle")
		if icon_name.is_empty():
			box.add_child(heading)
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(IconView.new(icon_name, Color("7A6F5C"), 26.0))
			row.add_child(heading)
			box.add_child(row)
	box.set_meta("panel", panel)
	return box


## Tam ekran kök kurulumu: arka plan + güvenli alan + dikey kutu. Dönen kutuya içerik eklenir.
static func screen_column(root: Control, separation := 12) -> VBoxContainer:
	var background := Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	root.add_child(ScreenBackdrop.new())
	var safe := MarginContainer.new()
	safe.set_script(load("res://scripts/ui/safe_area_container.gd"))
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(safe)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	safe.add_child(column)
	return column


static func scroll_box(min_height := 0.0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if min_height > 0.0:
		scroll.custom_minimum_size.y = min_height
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	list.set_meta("scroll", scroll)
	return list


static func locale() -> String:
	return "tr" if TranslationServer.get_locale().begins_with("tr") else "en"


static func money(minor: int, code := "") -> String:
	return Money.format(minor, code, locale())


## Kur (x RATE_SCALE) -> "29.70".
static func rate_text(rate: int) -> String:
	return Money.format(rate / 100, "", locale())


## Baz puan değişimi -> "+1.4%".
static func change_text(basis_points: int) -> String:
	return "%s%.1f%%" % ["+" if basis_points > 0 else "", basis_points / 100.0]


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Ekran açılışında geçiş animasyonu sürerken SceneManager yeni geçişi yutar; bitmesini bekleyip yönlendirir.
static func redirect_when_idle(tree: SceneTree, path: String) -> void:
	var scenes := tree.root.get_node("SceneManager")
	for i in 120:
		if not scenes.is_busy():
			break
		await tree.process_frame
	scenes.goto(path)
