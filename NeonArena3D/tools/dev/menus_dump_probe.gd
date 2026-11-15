extends SceneTree
## Menü davranış-eşdeğerlik probu (F3). Menü düğüm ağacını (ad, sınıf, metin, konum, boyut, görünürlük, opaklık) ve etkileşimleri
## (sinyaller, ekran geçişleri, klavye/geri, dil değişiminde yeniden kurulum, kenar boşlukları) her ekran × (dokunmatik, dil)
## için dökerek yazdırır. Menü kodu değiştiren bir görevden ÖNCE ve SONRA çalıştırıp çıktıları `diff` ile karşılaştırın:
##   godot --headless --path . -s res://tools/dev/menus_dump_probe.gd -- --no-save > build/menus_before.txt
## Bu araç doğrulama kapısında (verify.sh) YOKTUR; çıktısı belirleyicidir (iki koşu aynı). Bir görev ekran yapısını bilerek
## değiştiriyorsa fark beklenir ve gözden geçirilir. Gerçek kayda yazmaz (--no-save).

var scene
var m
var log_lines: PackedStringArray = []
var sig_log: PackedStringArray = []

func _initialize() -> void:
	_run.call_deferred()

func _p(s: String) -> void:
	print(s)

func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout

func _dump(n: Node, depth: int) -> void:
	var line := "  ".repeat(depth) + "%s <%s>" % [n.name, n.get_class()]
	if n is Control:
		var c := n as Control
		line += " v=%s pos=%s size=%s min=%s a=%.2f" % [str(c.visible), _v(c.position), _v(c.size), _v(c.get_combined_minimum_size()), c.modulate.a]
		line += " anc=%.2f,%.2f,%.2f,%.2f" % [c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom]
	if n is Label:
		line += " text=%s" % JSON.stringify((n as Label).text)
	if n is BaseButton:
		line += " dis=%s pressed=%s" % [str((n as BaseButton).disabled), str((n as BaseButton).button_pressed)]
		if n is Button:
			line += " text=%s" % JSON.stringify((n as Button).text)
	if n is Range:
		line += " val=%.3f" % (n as Range).value
	_p(line)
	for ch in n.get_children():
		_dump(ch, depth + 1)

func _v(v: Vector2) -> String:
	return "(%.1f,%.1f)" % [v.x, v.y]

func _state(label: String) -> void:
	_p("=== %s  current=%s in_game=%s children=%d" % [label, m.current, str(m.in_game), m.get_child_count()])
	for ch in m.get_children():
		if ch is Control and (ch as Control).visible:
			_dump(ch, 1)
	var names: PackedStringArray = []
	for ch in m.get_children():
		names.append("%s:%s" % [ch.name, str((ch as Control).visible)])
	_p("  children: " + ", ".join(names))

func _find_buttons(n: Node, out: Array) -> void:
	if n is Button and (n as Button).is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_find_buttons(ch, out)

func _press(text_tr: String) -> void:
	var btns: Array = []
	_find_buttons(m, btns)
	for b in btns:
		if (b as Button).text == text_tr:
			(b as Button).pressed.emit()
			return
	_p("  !! düğme yok: " + text_tr)

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = code as Key
	e.keycode = code as Key
	m._unhandled_input(e)

func _pause_action() -> void:
	var e := InputEventAction.new()
	e.action = "pause"
	e.pressed = true
	m._unhandled_input(e)

func _sigs() -> void:
	for sname in ["play_pressed", "resume_pressed", "restart_pressed", "menu_pressed", "pause_requested", "reroll_pressed", "quality_changed"]:
		m.connect(sname, func(): sig_log.append(sname))
	m.card_picked.connect(func(i): sig_log.append("card_picked:%d" % i))
	m.ship_preview.connect(func(id): sig_log.append("ship_preview:" + id))

func _flush(label: String) -> void:
	_p("  signals[%s]: %s" % [label, ",".join(sig_log)])
	sig_log.clear()

func _build_items() -> Array:
	var items: Array = []
	for i in 4:
		items.append({"card": root.get_node("GameData").cards[i], "count": i + 1})
	return items

func _scenario(touch: bool, lang: String) -> void:
	var settings = root.get_node("Settings")
	settings.touch = touch
	settings.meta.cores = 2300
	root.get_node("I18n").set_language(lang)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await _wait(0.5)
	m = scene.menus
	sig_log.clear()
	_sigs()
	_p("##### touch=%s lang=%s" % [str(touch), lang])
	_p("  menus tree children=%d" % m.get_child_count())
	m.show_main()
	await _wait(0.6)
	_state("main")
	m.notify("TEST DUYURU", 1.0)
	await _wait(0.5)
	_state("main+notice")
	_press(m.tr("OYNA")); _flush("OYNA")
	for dest in ["hangar", "workshop", "settings", "howto"]:
		m.show_main()
		await _wait(0.3)
		m.open_sub(dest, "main")
		await _wait(0.6)
		_state(dest)
		if dest == "hangar":
			for step in 3:
				_key(KEY_RIGHT)
				await _wait(0.3)
			_state("hangar+3 right")
			_press(m.tr("SEÇ")); _flush("hangar SEÇ")
			_key(KEY_LEFT); _key(KEY_A); await _wait(0.2)
			_state("hangar after left,a")
			m._hangar_act() if false else null
			m._back(); _flush("hangar back")
			_state("after hangar back")
		elif dest == "workshop":
			var tiles: Array = []
			_find_tiles(m, tiles)
			_p("  tiles=%d" % tiles.size())
			for t in tiles.slice(0, 3):
				(t as BaseButton).pressed.emit()
			await _wait(0.3)
			_state("workshop after buy x3")
			m._back(); _flush("workshop back")
		elif dest == "settings":
			_press(m.tr(m.get_node("/root/Settings").QUALITY_NAMES[m.get_node("/root/Settings").quality])); _flush("quality")
			await _wait(0.2)
			_state("settings after quality")
			# dil değişimi: yeniden kurulum yolu
			var other := "en" if lang == "tr" else "tr"
			root.get_node("I18n").set_language(other)
			await _wait(0.8)
			_state("settings after rebuild(" + other + ")")
			root.get_node("I18n").set_language(lang)
			await _wait(0.8)
			_state("settings after rebuild back(" + lang + ")")
			m._back(); _flush("settings back")
		else:
			m._back(); _flush("howto back")
	# duraklat
	m.in_game = true
	m.hide_all()
	await _wait(0.3)
	_state("hidden in_game")
	_pause_action(); _flush("esc in game")
	m.show_pause(7, 4, 12345, _build_items())
	await _wait(0.6)
	_state("pause")
	_press(m.tr("DEVAM ET")); _press(m.tr("YENİDEN BAŞLA")); _press(m.tr("ANA MENÜ")); _flush("pause buttons")
	_pause_action(); _flush("esc pause")
	m.open_sub("settings", "pause")
	await _wait(0.6)
	_state("pause->settings")
	root.get_node("I18n").set_language("en" if lang == "tr" else "tr")
	await _wait(0.8)
	_state("pause->settings after rebuild")
	root.get_node("I18n").set_language(lang)
	await _wait(0.8)
	m._back()
	await _wait(0.4)
	_state("settings back to pause")
	m.hide_all()
	# kartlar
	var cards: Array = [root.get_node("GameData").cards[0], root.get_node("GameData").cards[5], root.get_node("GameData").cards[root.get_node("GameData").cards.size() - 1]]
	m.show_cards(cards, 4, 2, {str(root.get_node("GameData").cards[0].get("id", "")): 2})
	await _wait(1.2)
	_state("cards")
	_key(KEY_1); _key(KEY_KP_2); _key(KEY_3); _key(KEY_4); _flush("cards keys")
	_press(m.tr("YENİLE  (%d)") % 2); _flush("reroll")
	m.show_cards(cards, 5, 0, {})
	await _wait(1.2)
	_state("cards reroll 0")
	m.hide_all()
	# oyun sonu
	m.show_gameover({"score": 12345, "best": 20000, "record": false, "wave": 9, "level": 7, "kills": 321, "combo": 44, "time": 305.0, "cores": 88, "total_cores": 2388}, _build_items())
	await _wait(4.0)
	_state("gameover")
	_key(KEY_R); _pause_action(); _flush("gameover R + esc")
	m.show_gameover({"score": 5, "best": 5, "record": true, "wave": 1, "level": 1, "kills": 0, "combo": 0, "time": 4.0, "cores": 0, "total_cores": 2300}, [])
	await _wait(1.0)
	_state("gameover record empty build")
	_press(m.tr("TEKRAR OYNA")); _press(m.tr("ANA MENÜ")); _flush("gameover buttons")
	# geri tuşu / ESC çizelgesi
	for s in ["main", "settings", "howto", "workshop", "hangar", "pause", "gameover", ""]:
		m.in_game = true
		if s == "main":
			m.show_main()
		elif s == "":
			m.hide_all()
		elif s in ["settings", "howto", "workshop", "hangar"]:
			m.open_sub(s, "main")
		elif s == "pause":
			m.show_pause(1, 1, 1, [])
		else:
			m.show_gameover({"score": 1}, [])
		await _wait(0.1)
		m._go_back()
		_p("  go_back(%s) -> current=%s sig=%s" % [s, m.current, ",".join(sig_log)])
		sig_log.clear()
	# kenar boşlukları
	m.set_margins(Vector4(60, 40, 70, 50))
	m.show_main()
	await _wait(0.5)
	_state("main after margins")
	scene.queue_free()
	await _wait(0.3)

func _find_tiles(n: Node, out: Array) -> void:
	if n is BaseButton and not (n is Button) and n.get_script() != null and "def" in n:
		out.append(n)
	for ch in n.get_children():
		_find_tiles(ch, out)

func _run() -> void:
	for touch in [false, true]:
		for lang in ["tr", "en"]:
			await _scenario(touch, lang)
	_p("PROBE BİTTİ")
	quit(0)
