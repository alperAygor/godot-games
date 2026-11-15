class_name MenuLogic
extends RefCounted
## Menülerin SAF karar mantığı (düğüm yok): geri tuşu yönlendirmesi, klavye eşlemeleri, hangar sayfalama/düğme durumu.
## tests/unit/test_menu_logic.gd ile sınanır; menus.gd ve ekran modülleri bunları kullanır.

enum BackAction { NONE, BACK, RESUME, QUIT, MENU, PAUSE }
enum ShipButton { SELECTED, SELECT, UNLOCK }

## Ekranlarda "geri" (ESC / Android geri tuşu) ne yapar.
static func back_action(screen: String, in_game: bool, mobile: bool) -> BackAction:
	match screen:
		"settings", "howto", "workshop", "hangar":
			return BackAction.BACK
		"pause":
			return BackAction.RESUME
		"main":
			return BackAction.QUIT if mobile else BackAction.NONE
		"gameover":
			return BackAction.MENU
		"":
			return BackAction.PAUSE if in_game else BackAction.NONE
	return BackAction.NONE


## Kart ekranında 1/2/3 (üst sıra ve sayı tuş takımı) -> kart dizini; başka tuş -1.
static func card_index_for_key(physical_keycode: int) -> int:
	match physical_keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
	return -1


## Hangar'da sol/sağ tuşları -> adım (-1 / +1); başka tuş 0.
static func hangar_step_for_key(physical_keycode: int) -> int:
	if physical_keycode in [KEY_LEFT, KEY_A]:
		return -1
	if physical_keycode in [KEY_RIGHT, KEY_D]:
		return 1
	return 0


## Döngüsel dizin (gemi listesi).
static func wrap_index(index: int, delta: int, count: int) -> int:
	return posmod(index + delta, count) if count > 0 else 0


## Hangar eylem düğmesi: seçili gemi / sahip olunan (SEÇ) / satın alınacak (AÇ).
static func ship_button(selected: bool, owned: bool) -> ShipButton:
	if selected:
		return ShipButton.SELECTED
	return ShipButton.SELECT if owned else ShipButton.UNLOCK


static func page_text(index: int, count: int) -> String:
	return "%d / %d" % [index + 1, count]
