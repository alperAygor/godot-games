class_name RetentionUi
extends RefCounted

## Üç sayfanın ortak küçük parçaları. Düz, çizgisiz, küçük ikonlu; renkler UiKit'ten.

const ROW_BG: Color = Color("f3efe3")
const WARM_SOFT: Color = Color("fbebc6")
const STAR_COLOR: Color = Color("f0a53a")
const TITLE_SIZE: int = 48
const BODY_SIZE: int = 30
const SMALL_SIZE: int = 28
const GAP: float = 24.0
const DISC_DIAMETER: float = 92.0
const DISC_ICON: float = 44.0
const ROW_RADIUS: int = 40
const REWARD_ICON: float = 34.0
const FLOAT_RISE: float = 90.0
const FLOAT_SECONDS: float = 1.0
const FLOAT_FONT: int = 52
const CHEST_ICON: String = "lucide/package"
const COIN_ICON: String = "lucide/coins"
const STAR_ICON: String = "lucide/star"
const CHECK_ICON: String = "lucide/check"
const CLOCK_ICON: String = "lucide/clock"
const FLAME_ICON: String = "lucide/flame"
const BOOSTER_ICONS: Dictionary = {
	"undo": "lucide/rotate-ccw",
	"pin_remover": "lucide/zap",
	"extra_slot": "lucide/plus",
}


static func booster_icon(id: String) -> String:
	return String(BOOSTER_ICONS.get(id, CHEST_ICON))


static func disc(icon_name: String, bg: Color, fg: Color, diameter: float = DISC_DIAMETER,
		icon_pixels: float = DISC_ICON) -> Panel:
	var node: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(int(diameter * 0.5))
	box.anti_aliasing = true
	node.add_theme_stylebox_override("panel", box)
	node.custom_minimum_size = Vector2(diameter, diameter)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon: TextureRect = UiKit.tinted_icon(icon_name, icon_pixels, fg)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(icon)
	return node


## Yuvarlak köşeli düz satır kartı; içine `inner` konur.
static func row_card(margin_x: int = 28, margin_y: int = 22) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = ROW_BG
	box.set_corner_radius_all(ROW_RADIUS)
	box.anti_aliasing = true
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	card.add_theme_stylebox_override("panel", box)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


static func left_label(text: String, font_size: int, color: Color = UiKit.TEXT) -> Label:
	var node: Label = UiKit.label(text, font_size, color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return node


## [jeton] +N  [yıldız] +N  [güçlendirici] +N — bir ödülün küçük özeti.
static func reward_chips(reward: Dictionary, font_size: int = BODY_SIZE,
		color: Color = UiKit.TEXT) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coins: int = int(reward.get("coins", 0))
	if coins > 0:
		_chip(row, COIN_ICON, UiKit.GOLD, "+%d" % coins, font_size, color)
	var stars: int = int(reward.get("stars", 0))
	if stars > 0:
		_chip(row, STAR_ICON, STAR_COLOR, "+%d" % stars, font_size, color)
	var boosters: Variant = reward.get("boosters", {})
	if boosters is Dictionary:
		for id: Variant in (boosters as Dictionary).keys():
			_chip(row, booster_icon(String(id)), UiKit.ACCENT, "+%d" % int((boosters as Dictionary)[id]),
				font_size, color)
	return row


static func _chip(row: HBoxContainer, icon_name: String, tint: Color, text: String, font_size: int,
		color: Color) -> void:
	if row.get_child_count() > 0:
		row.add_child(UiKit.spacer(10.0))
	var icon: TextureRect = UiKit.tinted_icon(icon_name, REWARD_ICON, tint)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(UiKit.label(text, font_size, color))


## Önizleme için şablonu (booster: "any") görsel ödüle çevirir: "any" -> tek rozet, sayı korunur.
static func preview(template: Dictionary) -> Dictionary:
	var shown: Dictionary = RetentionRewards.empty()
	shown["coins"] = int(template.get("coins", 0))
	shown["stars"] = int(template.get("stars", 0))
	var want: String = String(template.get("booster", ""))
	if not want.is_empty() and int(template.get("count", 0)) > 0:
		(shown["boosters"] as Dictionary)[want if want != RetentionRewards.BOOSTER_ANY else "any"] = int(template["count"])
	return shown


## Alınabilir/alınmış durumu için kısa "pop" animasyonu.
static func pop(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * 0.7
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ödül anı: kıvılcım + yukarı süzülen metin. `host` sayfanın kökü, `at` onun yerel koordinatı.
static func celebrate(host: Control, at: Vector2, text: String) -> void:
	RetBurst.play(host, at)
	var label: Label = UiKit.label(text, FLOAT_FONT, UiKit.GOLD)
	label.position = at - Vector2(120.0, 40.0)
	label.size = Vector2(240.0, 80.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(label)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - FLOAT_RISE, FLOAT_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_SECONDS).set_delay(FLOAT_SECONDS * 0.4)
	tween.chain().tween_callback(label.queue_free)


## Yukarı süzülen yazı: jeton varsa "+30" (yıldız/güçlendirici ödül satırında zaten görünür).
static func reward_text(reward: Dictionary) -> String:
	return "+%d" % int(reward.get("coins", 0)) if int(reward.get("coins", 0)) > 0 else ""


static func dot(color: Color, size: float) -> Panel:
	var node: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(size))
	box.anti_aliasing = true
	node.add_theme_stylebox_override("panel", box)
	node.size = Vector2(size, size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Alev + sayı satırı (oturum serisi).
static func flame_row(count: int, font_size: int = SMALL_SIZE) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lit: bool = count > 0
	var icon: TextureRect = UiKit.tinted_icon(FLAME_ICON, REWARD_ICON, UiKit.FLAME if lit else UiKit.DISC_OFF)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(UiKit.label(str(count), font_size, UiKit.TEXT if lit else UiKit.TEXT_MUTED))
	return row
