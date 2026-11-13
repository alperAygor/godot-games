class_name ZenCard
extends Sheet

## Zen giriş kartı (haritadan açılır): yaprak ikonu, kısa açıklama, toplam sayaç ve "Başla".
## Seviye yetmiyorsa kilitli görünür ve hangi seviyede açılacağı yazar. Düz, çizgisiz, az metin.

signal started

const TITLE_SIZE: int = 56
const BODY_SIZE: int = 34
const SMALL_SIZE: int = 30
const DISC: float = 150.0
const ICON_PIXELS: float = 72.0
const GAP: float = 28.0
const BUTTON_HEIGHT: float = 132.0


static func open(parent: Node) -> ZenCard:
	var card: ZenCard = ZenCard.new()
	card.build(parent, false)
	card.dismiss_on_dim = true
	card._fill()
	card.play_intro()
	return card


func _fill() -> void:
	var unlocked: bool = ZenMode.is_unlocked(Progress.level())
	var column: VBoxContainer = content()
	var disc_wrap: CenterContainer = CenterContainer.new()
	disc_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.ACCENT_SOFT if unlocked else UiKit.DISC_OFF
	box.set_corner_radius_all(int(DISC * 0.5))
	box.anti_aliasing = true
	disc.add_theme_stylebox_override("panel", box)
	disc.custom_minimum_size = Vector2(DISC, DISC)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = MapIcons.rect("leaf" if unlocked else "lock", ICON_PIXELS,
		UiKit.ACCENT if unlocked else UiKit.TEXT_MUTED)
	icon.position = Vector2(DISC - ICON_PIXELS, DISC - ICON_PIXELS) * 0.5
	disc.add_child(icon)
	disc_wrap.add_child(disc)
	column.add_child(disc_wrap)
	column.add_child(UiKit.spacer(GAP))
	column.add_child(UiKit.label(Loc.t("ZEN_TITLE"), TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP * 0.4))
	var sub: Label = UiKit.label(Loc.t("ZEN_SUB") if unlocked else Loc.f("ZEN_LOCKED", [ZenMode.unlock_level()]),
		BODY_SIZE, UiKit.TEXT_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)
	if unlocked and ZenMode.total_cleared() > 0:
		column.add_child(UiKit.spacer(GAP * 0.5))
		column.add_child(UiKit.label(Loc.n("ZEN_TOTAL_ONE", "ZEN_TOTAL_OTHER", ZenMode.total_cleared()) % ZenMode.total_cleared(), SMALL_SIZE, UiKit.TEXT_MUTED))
	column.add_child(UiKit.spacer(GAP * 1.4))
	if unlocked:
		var start: Button = UiKit.button(Loc.t("ZEN_START"), &"", "lucide/play", BUTTON_HEIGHT)
		start.pressed.connect(_on_start)
		column.add_child(start)
	else:
		var ok: Button = UiKit.button(UiStrings.ok(), &"SecondaryButton", "", BUTTON_HEIGHT)
		ok.pressed.connect(close)
		column.add_child(ok)


func _on_start() -> void:
	started.emit()
	ZenMode.request_start()
	GameManager.start_game()
