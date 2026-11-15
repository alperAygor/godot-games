class_name UiToast
extends PanelContainer

## Kısa, sakin bildirim hapı (ör. "Şu an reklam yok"). Koyu düz zemin, açık yazı; birkaç saniye sonra solup silinir.
## Tek örnek kuralı: aynı ebeveyne yeni toast gelince eskisi silinir (yığılmaz).

const SHOW_SECONDS: float = 2.4
const FADE_IN_SECONDS: float = 0.18
const FADE_OUT_SECONDS: float = 0.3
const FONT_SIZE: int = UiKit.TYPE_CAPTION + 2
const PAD_X: int = 36
const PAD_Y: int = 20
const MAX_WIDTH: float = 880.0
const ICON_PIXELS: float = 36.0
const ICON_GAP: int = UiTokens.SPACE_SM
const GROUP: StringName = &"ui_toast"


## `bottom_offset`: ebeveynin alt kenarından yukarı uzaklık (px, viewport birimi).
## `icon_name`: metnin solunda küçük ikon (nedeni bir bakışta anlatır; boşsa yalnız metin).
static func show_text(parent: Control, text: String, bottom_offset: float, icon_name: String = "") -> UiToast:
	for old: Node in parent.get_children():
		if old is UiToast:
			old.queue_free()
	var toast: UiToast = UiToast.new()
	toast._build(text, bottom_offset, icon_name)
	parent.add_child(toast)
	toast._play()
	return toast


func _build(text: String, bottom_offset: float, icon_name: String) -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box: StyleBoxFlat = UiKit.card_style(UiKit.TEXT, UiTokens.RADIUS_PILL, PAD_X, PAD_Y)
	add_theme_stylebox_override("panel", box)
	var caption: Label = UiKit.wrap_label(text, FONT_SIZE, Color.WHITE)
	# Metne göre daralır, en çok MAX_WIDTH olur (uzun EN/ES metin alt satıra kırılır).
	var font: Font = load(UiKit.FONT_PATH) as Font
	var wanted: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x if font != null else MAX_WIDTH
	caption.custom_minimum_size.x = minf(wanted + 2.0, MAX_WIDTH - ICON_PIXELS - ICON_GAP)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ICON_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	if not icon_name.is_empty() and Icons.texture(icon_name) != null:
		var icon: TextureRect = UiKit.tinted_icon(icon_name, ICON_PIXELS, Color(1.0, 1.0, 1.0, 0.9))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	row.add_child(caption)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -bottom_offset
	offset_top = -bottom_offset
	modulate.a = 0.0


func _play() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)
	tween.tween_interval(SHOW_SECONDS)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	tween.tween_callback(queue_free)
