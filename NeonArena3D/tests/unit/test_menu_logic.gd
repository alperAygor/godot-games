extends TestCase
## MenuLogic: geri tuşu yönlendirmesi, klavye eşlemeleri, hangar sayfalama ve düğme durumu (düğümsüz saf mantık).

func test_back_action_table() -> void:
	var B := MenuLogic.BackAction
	for s in ["settings", "howto", "workshop", "hangar"]:
		eq(MenuLogic.back_action(s, false, false), B.BACK, "%s: geri" % s)
		eq(MenuLogic.back_action(s, true, true), B.BACK, "%s: oyunda/mobilde de geri" % s)
	eq(MenuLogic.back_action("pause", true, false), B.RESUME, "duraklatma: devam")
	eq(MenuLogic.back_action("gameover", true, false), B.MENU, "oyun sonu: ana menü")
	eq(MenuLogic.back_action("main", false, true), B.QUIT, "ana menü + mobil: çık")
	eq(MenuLogic.back_action("main", false, false), B.NONE, "ana menü + masaüstü: hiçbir şey")
	eq(MenuLogic.back_action("", true, false), B.PAUSE, "oyun içi: duraklat")
	eq(MenuLogic.back_action("", false, false), B.NONE, "menüde değil, oyunda değil: yok")
	eq(MenuLogic.back_action("cards", true, false), B.NONE, "kart seçiminde geri yok")
	eq(MenuLogic.back_action("bilinmeyen", true, true), B.NONE, "bilinmeyen ekran: yok")

func test_card_keys() -> void:
	eq(MenuLogic.card_index_for_key(KEY_1), 0, "1")
	eq(MenuLogic.card_index_for_key(KEY_KP_1), 0, "KP 1")
	eq(MenuLogic.card_index_for_key(KEY_2), 1, "2")
	eq(MenuLogic.card_index_for_key(KEY_KP_2), 1, "KP 2")
	eq(MenuLogic.card_index_for_key(KEY_3), 2, "3")
	eq(MenuLogic.card_index_for_key(KEY_KP_3), 2, "KP 3")
	eq(MenuLogic.card_index_for_key(KEY_4), -1, "4 yok")
	eq(MenuLogic.card_index_for_key(KEY_R), -1, "R yok")

func test_hangar_keys() -> void:
	eq(MenuLogic.hangar_step_for_key(KEY_LEFT), -1, "sol ok")
	eq(MenuLogic.hangar_step_for_key(KEY_A), -1, "A")
	eq(MenuLogic.hangar_step_for_key(KEY_RIGHT), 1, "sağ ok")
	eq(MenuLogic.hangar_step_for_key(KEY_D), 1, "D")
	eq(MenuLogic.hangar_step_for_key(KEY_UP), 0, "yukarı yok")

func test_wrap_index() -> void:
	eq(MenuLogic.wrap_index(0, -1, 4), 3, "başta geri: sona sarar")
	eq(MenuLogic.wrap_index(3, 1, 4), 0, "sonda ileri: başa sarar")
	eq(MenuLogic.wrap_index(1, 1, 4), 2, "normal ileri")
	eq(MenuLogic.wrap_index(2, -5, 4), 1, "büyük adım")
	eq(MenuLogic.wrap_index(0, 1, 0), 0, "boş liste: 0")

func test_ship_button_state() -> void:
	eq(MenuLogic.ship_button(true, true), MenuLogic.ShipButton.SELECTED, "seçili")
	eq(MenuLogic.ship_button(false, true), MenuLogic.ShipButton.SELECT, "sahip, seçili değil: SEÇ")
	eq(MenuLogic.ship_button(false, false), MenuLogic.ShipButton.UNLOCK, "sahip değil: AÇ")
	eq(MenuLogic.ship_button(true, false), MenuLogic.ShipButton.SELECTED, "seçili her zaman önce")

func test_page_text() -> void:
	eq(MenuLogic.page_text(0, 4), "1 / 4", "ilk sayfa")
	eq(MenuLogic.page_text(3, 4), "4 / 4", "son sayfa")
