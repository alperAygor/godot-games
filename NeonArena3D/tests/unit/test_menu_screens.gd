extends TestCase
## Menü ekran modülleri: kurulum, düğme sinyalleri, geri yönlendirmesi ve sonraki görevlerin kullanacağı seam'ler.
## Test çalıştırıcısı sahne ağacı hazır olmadan çalışır; bu yüzden `Menus` ağaç DIŞINDA `build_ui()` ile kurulur
## (ekran GÖSTERME/tween gerektiren akışlar tools/dev/menus_probe.gd ile gerçek sahnede sınanır).

const MenusScript = preload("res://scripts/ui/menus.gd")
const SCREEN_IDS := ["main", "hangar", "workshop", "settings", "howto", "pause", "cards", "gameover"]

func _menus() -> Control:
	var m: Control = MenusScript.new()
	m.build_ui()
	return m

func test_all_screens_built_and_hidden() -> void:
	var m := _menus()
	eq(m.modules.size(), SCREEN_IDS.size(), "8 ekran modülü")
	for id in SCREEN_IDS:
		check(m.modules.has(id), "modül: " + id)
		var r: Control = m.screen_root(id)
		check(r != null and not r.visible, "ekran kökü var ve gizli: " + id)
		eq(r.get_parent(), m, "kök menünün çocuğu: " + id)
	check(m.fade != null and m.fade.get_index() == m.get_child_count() - 1, "örtü (fade) en üstte")
	eq(m.get_child_count(), SCREEN_IDS.size() + 1, "8 ekran + örtü")
	eq(m.current, "", "başlangıçta ekran yok")
	m.free()

func test_screen_children_are_stable_order() -> void:
	## Ekran kökleri eski menus.gd sırasıyla çocuk olmalı (düğüm yolları değişmesin).
	var m := _menus()
	for i in SCREEN_IDS.size():
		eq(m.get_child(i), m.screen_root(SCREEN_IDS[i]), "çocuk %d = %s" % [i, SCREEN_IDS[i]])
	m.free()

func test_button_signals() -> void:
	var m := _menus()
	var log: Array = []
	m.play_pressed.connect(func(): log.append("play"))
	m.resume_pressed.connect(func(): log.append("resume"))
	m.restart_pressed.connect(func(): log.append("restart"))
	(m.focus["main"] as Button).pressed.emit()
	(m.focus["pause"] as Button).pressed.emit()
	(m.focus["gameover"] as Button).pressed.emit()
	eq(log, ["play", "resume", "restart"], "OYNA / DEVAM ET / TEKRAR OYNA")
	check(m.focus.has("settings") and m.focus.has("howto") and m.focus.has("hangar") and m.focus.has("workshop"), "odak hedefleri tamam")
	m.free()

func test_go_back_routes_by_screen() -> void:
	var m := _menus()
	var log: Array = []
	m.pause_requested.connect(func(): log.append("pause"))
	m.resume_pressed.connect(func(): log.append("resume"))
	m.menu_pressed.connect(func(): log.append("menu"))
	m.in_game = true
	m.current = ""
	m._go_back()
	m.current = "pause"
	m._go_back()
	m.current = "gameover"
	m._go_back()
	m.current = "cards"
	m._go_back()
	eq(log, ["pause", "resume", "menu"], "geri yönlendirmesi (kartlarda yok)")
	m.free()

func test_seam_main_add_entry() -> void:
	var m := _menus()
	var entry := Button.new()
	m.main.add_entry(entry)
	eq(entry.get_parent(), m.main.column, "ana sütunda")
	if m.main.quit_button != null:
		eq(entry.get_index(), m.main.quit_button.get_index() - 1, "ÇIKIŞ'ın hemen önünde")
		eq(m.main.quit_button.get_index(), m.main.column.get_child_count() - 1, "ÇIKIŞ hâlâ sonda")
	var second := Button.new()
	m.main.add_entry(second, 2)
	eq(second.get_index(), 2, "belirtilen sıraya")
	m.free()

func test_seam_settings_add_row_before_back() -> void:
	var m := _menus()
	var box: VBoxContainer = m.settings.box
	var count_before := box.get_child_count()
	var row: HBoxContainer = m.settings.add_row("GİZLİLİK", Button.new())
	eq(box.get_child_count(), count_before + 1, "bir satır eklendi")
	eq(row.get_index(), count_before - 2, "boşluk+GERİ düğmesinin öncesinde")
	check(box.get_child(box.get_child_count() - 1) is Button, "GERİ düğmesi hâlâ sonda")
	var row2: HBoxContainer = m.settings.add_row("BAŞKA", Button.new())
	eq(row2.get_index(), row.get_index() + 1, "ikinci satır birincinin altında")
	m.free()

func test_seam_gameover_cards_workshop() -> void:
	var m := _menus()
	var ad := Button.new()
	m.gameover.add_reward_action(ad)
	eq(ad.get_index(), m.gameover.reward_row.get_index() + 1, "çekirdek satırının hemen altında")
	var reroll_ad := Button.new()
	m.cards.add_below_reroll(reroll_ad)
	eq(reroll_ad.get_index(), m.cards.reroll_button.get_index() + 1, "YENİLE'nin altında")
	var shop := Button.new()
	m.workshop.add_footer(shop)
	eq(shop.get_index(), m.workshop.box.get_child_count() - 2, "GERİ'nin üstünde")
	m.free()

func test_rebuild_drops_seam_controls_and_recreates_modules() -> void:
	## Seam denetimleri modülle birlikte gider; screens_rebuilt sinyali yeniden uygulama içindir (belgelenmiş sözleşme).
	var m := _menus()
	var old_main = m.main
	var entry := Button.new()
	m.main.add_entry(entry)
	m.clear_screens()
	m._build_all()
	check(m.main != old_main, "modül yeniden kuruldu")
	check(entry.get_parent() == null or entry.get_parent() != m.main.column, "seam denetimi yeni sütunda değil")
	eq(m.modules.size(), SCREEN_IDS.size(), "modül sayısı aynı")
	entry.free()
	m.free()

func test_set_margins_moves_main_column() -> void:
	var m := _menus()
	m.set_margins(Vector4(60, 40, 70, 50))
	near(m.main.column.offset_left, 116.0, 0.01, "sol kenar boşluğu + 56")
	near(m.main.column.offset_right, 676.0, 0.01, "genişlik 560")
	eq(m.margin, Vector4(60, 40, 70, 50), "kenar boşluğu saklandı")
	m.free()
