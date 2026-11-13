class_name DailyUi
extends RefCounted

## Günlük ekranların ortak küçük parçaları: ikonlu disk, ödül satırı, seri satırı.
## Düz, çizgisiz, küçük ikonlu (kullanıcı tercihi); renkler UiKit'ten.

const DISC: float = 112.0
const DISC_ICON: float = 52.0
const REWARD_ICON: float = 44.0
const REWARD_FONT: int = UiKit.TYPE_NUMERIC
const ROW_SEPARATION: int = 14
const GROUP_GAP: float = 36.0
const STREAK_ICON: float = 40.0
const STREAK_FONT: int = 40
const WARM_SOFT: Color = UiKit.COIN_SOFT


static func icon_disc(icon_name: String, disc_color: Color, icon_color: Color) -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = disc_color
	box.set_corner_radius_all(int(DISC * 0.5))
	box.anti_aliasing = true
	disc.add_theme_stylebox_override("panel", box)
	disc.custom_minimum_size = Vector2(DISC, DISC)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)
	var icon: TextureRect = UiKit.tinted_icon(icon_name, DISC_ICON, icon_color)
	icon.position = Vector2((DISC - DISC_ICON) * 0.5, (DISC - DISC_ICON) * 0.5)
	disc.add_child(icon)
	return holder


static func booster_icon(booster_id: String) -> String:
	return String(DailyStrings.BOOSTER_ICONS.get(booster_id, DailyStrings.DEFAULT_BOOSTER_ICON))


## [jeton ikonu] +N  [güçlendirici ikonu] +1 — ödül özeti. Dönen satırın ilk Label'ı jeton sayısıdır.
static func reward_row(coins: int, booster_id: String, booster_count: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin: TextureRect = UiKit.tinted_icon("lucide/coins", REWARD_ICON, UiKit.GOLD)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	row.add_child(UiKit.label(DailyStrings.REWARD_FORMAT % coins, REWARD_FONT))
	if booster_count > 0 and not booster_id.is_empty():
		row.add_child(UiKit.spacer(GROUP_GAP))
		var gift: TextureRect = UiKit.tinted_icon(booster_icon(booster_id), REWARD_ICON, UiKit.ACCENT)
		gift.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(gift)
		row.add_child(UiKit.label(DailyStrings.BOOSTER_FORMAT % booster_count, REWARD_FONT))
	return row


## Alev + seri sayısı; seri 0 ise sönük.
static func streak_row(streak: int, best: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lit: bool = streak > 0
	var flame: TextureRect = UiKit.tinted_icon("lucide/flame", STREAK_ICON,
		UiKit.FLAME if lit else UiKit.DISC_OFF)
	flame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flame)
	row.add_child(UiKit.label(DailyStrings.STREAK_FORMAT % streak, STREAK_FONT,
		UiKit.TEXT if lit else UiKit.TEXT_MUTED))
	if best > streak:
		row.add_child(UiKit.spacer(GROUP_GAP * 0.5))
		var cup: TextureRect = UiKit.tinted_icon("lucide/trophy", STREAK_ICON * 0.8, UiKit.TEXT_MUTED)
		cup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cup)
		row.add_child(UiKit.label(str(best), STREAK_FONT - 6, UiKit.TEXT_MUTED))
	return row
