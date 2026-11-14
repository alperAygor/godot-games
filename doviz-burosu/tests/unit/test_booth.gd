extends "res://tests/session_case.gd"
## Gişe sahnesi: fiziksel sürükle-bırak (banknot/belge, tepsiler), damga, müşteri yürüyüşü, konuşma balonu, çıkış animasyonu.

var desk: Control


func after_each() -> void:
	Feel.instant = DisplayServer.get_name() == "headless"
	await super.after_each()


func _open(day := 5, salt := "booth-test") -> void:
	var career := Career.load_default(salt)
	career.day = day
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	desk.play(career)
	for i in 3:
		await tree.process_frame


func _mouse_button(item: Control, global_point: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = global_point
	event.position = global_point - item.global_position
	return event


func _mouse_move(item: Control, global_point: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.global_position = global_point
	event.position = global_point - item.global_position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


## Bir nesneyi `to` global noktasına sürükleyip bırakır (gerçek fare olaylarıyla, adım adım).
func _drag(item: DraggableItem, to: Vector2) -> void:
	var from := item.global_position + item.size / 2.0
	item._gui_input(_mouse_button(item, from, true))
	var steps := 6
	var last := from
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		item._gui_input(_mouse_move(item, point, point - last))
		last = point
	item._gui_input(_mouse_button(item, last, false))
	await tree.process_frame


func _first_tile() -> NoteTile:
	return node("NotesGrid").get_child(0) as NoteTile


func test_tapping_a_note_still_inspects_it() -> void:
	await _open()
	await tap("NoteTile0")
	assert_true(node("InspectView") != null)


func test_a_short_press_is_a_tap_not_a_drag() -> void:
	await _open()
	var tile := _first_tile()
	var start := tile.position
	var center := tile.global_position + tile.size / 2.0
	tile._gui_input(_mouse_button(tile, center, true))
	tile._gui_input(_mouse_move(tile, center + Vector2(4, 2), Vector2(4, 2)))
	tile._gui_input(_mouse_button(tile, center + Vector2(4, 2), false))
	await tree.process_frame
	assert_eq(tile.position, start, "14 pikselden az hareket sürükleme değildir")
	assert_true(node("InspectView") != null, "dokunma sayılır")


func test_dragging_a_note_to_the_return_tray_sets_its_fate_and_seats_it() -> void:
	await _open()
	var tile := _first_tile()
	var tray := node("Zone_return") as Control
	await _drag(tile, tray.global_position + tray.size / 2.0)
	assert_eq(desk.model.fate(0), Verdict.FATE_RETURN)
	var seated_center := tile.global_position + tile.size * tile.scale.x / 2.0 + (tile.size - tile.size * tile.scale.x) / 2.0 * 0.0
	assert_true(tray.get_global_rect().has_point(tile.global_position + tile.size / 2.0), "banknot tepsinin içinde durur")
	assert_true(tile.scale.x < 1.0, "tepsiye küçülerek yerleşir")
	assert_eq(seated_center.is_finite(), true)


func test_dragging_a_note_out_of_a_tray_returns_it_to_accept() -> void:
	await _open()
	var tile := _first_tile()
	var tray := node("Zone_confiscate") as Control
	await _drag(tile, tray.global_position + tray.size / 2.0)
	assert_eq(desk.model.fate(0), Verdict.FATE_CONFISCATE)
	var items := node("Items") as Control
	await _drag(tile, items.global_position + Vector2(items.size.x * 0.5, items.size.y * 0.5))
	assert_eq(desk.model.fate(0), Verdict.FATE_ACCEPT)
	assert_eq(tile.scale, Vector2.ONE, "masaya dönünce normal boyut")


func test_a_note_dropped_on_the_desk_stays_where_it_was_put() -> void:
	await _open()
	var tile := _first_tile()
	var items := node("Items") as Control
	var target := items.global_position + Vector2(items.size.x * 0.5, items.size.y * 0.55)
	await _drag(tile, target)
	var center := tile.global_position + tile.size / 2.0
	assert_true(center.distance_to(target) < 24.0, "bırakıldığı yerde kalır (%s vs %s)" % [center, target])
	assert_eq(desk.model.fate(0), Verdict.FATE_ACCEPT)
	assert_eq(tile.home_position, tile.position, "yeni 'ev' konumu bırakılan yerdir")


func test_notes_cannot_be_dragged_off_the_desk() -> void:
	await _open()
	var tile := _first_tile()
	var items := node("Items") as Control
	await _drag(tile, items.global_position + Vector2(-400, -400))
	assert_true(tile.position.x >= 0.0 and tile.position.y >= 30.0, "masa sınırında durur: %s" % tile.position)


func test_documents_are_draggable_but_never_decide() -> void:
	await _open(10)
	var factory := CustomerFactory.new(desk.shift.ctx, Seed.rng("booth-docs"))
	var customer := factory.make_scenario("decl_signature")
	desk.shift.current = customer
	desk.shift.current_verdict = RuleEngine.new(desk.shift.ctx).evaluate(customer)
	desk.tick(0.0)
	for i in 3:
		await tree.process_frame
	var docs := node("DocsRow").get_children()
	assert_eq(docs.size(), 2, "kimlik ve beyan")
	var doc := docs[0] as DocTile
	var tray := node("Zone_return") as Control
	await _drag(doc, tray.global_position + tray.size / 2.0)
	for i in desk.shift.current.notes.size():
		assert_eq(desk.model.fate(i), Verdict.FATE_ACCEPT, "belge bir tepsiye bırakılınca banknotların kaderi değişmez")


func test_items_lie_slightly_crooked_but_inside_the_desk() -> void:
	await _open()
	var items := node("Items") as Control
	for tile: Control in node("NotesGrid").get_children():
		assert_true(absf(tile.rotation) <= 0.05, "hafif çarpık")
		assert_true(Rect2(Vector2.ZERO, items.size).grow(8.0).encloses(Rect2(tile.position, tile.size)), "masanın içinde: %s %s items %s" % [tile.position, tile.size, items.size])


func test_many_notes_are_shrunk_to_fit_the_desk() -> void:
	await _open(13, "booth-many")
	var items := node("Items") as Control
	var rect := Rect2(Vector2.ZERO, items.size).grow(8.0)
	for tile: Control in node("NotesGrid").get_children():
		assert_true(rect.encloses(Rect2(tile.position, tile.size)), "sığmalı")


func test_stamp_buttons_keep_their_names_and_work_as_decisions() -> void:
	await _open()
	assert_true(node("CompleteButton") is StampButton)
	assert_true(node("RejectButton") is StampButton)
	assert_true(node("PoliceButton") is StampButton)
	await tap("PoliceButton")
	assert_eq(desk.shift.stats["served"], 1)
	assert_true(node("ReceiptInk") != null, "fişe mühür izi basılır")
	assert_eq((node("ReceiptInk") as Label).text, "POLİS")


func test_receipt_ink_is_cleared_when_the_next_customer_arrives() -> void:
	await _open()
	await tap("PoliceButton")
	desk.tick(3.0)
	await tree.process_frame
	assert_true(node("ReceiptInk") == null)


# --- Animasyonlar (gerçek zamanlı) -----------------------------------------------------------------------

func test_customer_walks_in_then_speaks_with_typing() -> void:
	Feel.instant = false
	await _open()
	var booth := node("BoothView") as BoothView
	var figure := booth.figure
	assert_true(figure.position.x > figure.rest_x + 100.0, "kapıdan, sağdan gelmeye başlar")
	assert_false(booth.bubble.visible, "yürürken konuşmaz")
	await tree.create_timer(1.35).timeout
	assert_true(absf(figure.position.x - figure.rest_x) < 3.0, "durma noktasına varır")
	assert_true(booth.bubble.visible and booth.bubble.typing, "durunca balon yazmaya başlar")
	assert_eq(booth.bubble.label.text, desk._speech(desk.shift.current), "metin hep tam durur, yalnızca görünen harf artar")
	assert_true(booth.bubble.label.visible_characters < booth.bubble.label.text.length())
	await tree.create_timer(2.0).timeout
	assert_false(booth.bubble.typing)
	assert_eq(booth.bubble.label.visible_characters, -1)


func test_tapping_the_bubble_finishes_the_sentence() -> void:
	Feel.instant = false
	await _open()
	await tree.create_timer(1.4).timeout
	var bubble := (node("BoothView") as BoothView).bubble
	assert_true(bubble.typing)
	bubble._gui_input(_mouse_button(bubble, bubble.global_position + Vector2(5, 5), true))
	assert_false(bubble.typing)
	assert_eq(bubble.label.visible_characters, -1)


func test_notes_slide_in_from_the_slot_and_land_in_place() -> void:
	Feel.instant = false
	await _open()
	var tile := _first_tile()
	assert_true(tile.modulate.a < 1.0, "yuvadan çıkana dek görünmez; sonra kayarak gelir (a=%s pos=%s home=%s inst=%s)" % [tile.modulate.a, tile.position, tile.home_position, Feel.instant])
	await tree.create_timer(1.6).timeout
	assert_true(tile.position.distance_to(tile.home_position) < 2.0)
	assert_eq(tile.modulate.a, 1.0)


func test_customer_walks_away_after_the_decision() -> void:
	Feel.instant = false
	await _open()
	await tree.create_timer(1.4).timeout
	var figure := (node("BoothView") as BoothView).figure
	var before := figure.position.x
	desk._decide(Verdict.DECISION_POLICE, "")
	await tree.create_timer(0.5).timeout
	assert_true(figure.position.x < before - 40.0, "sola yürür")
	await tree.create_timer(0.9).timeout
	assert_false(figure.visible)
	assert_true(node("Leaving") == null or node("Leaving").modulate.a < 0.1, "kâğıtlar süpürüldü")


func test_the_speaking_mouth_moves_only_while_talking() -> void:
	Feel.instant = false
	await _open()
	await tree.create_timer(1.4).timeout
	var figure := (node("BoothView") as BoothView).figure
	var seen := {}
	for i in 12:
		seen[snappedf(figure.face.mouth_open, 0.1)] = true
		await tree.create_timer(0.05).timeout
	assert_true(seen.size() > 1, "konuşurken ağız oynar")
	await tree.create_timer(2.5).timeout
	assert_eq(figure.face.mouth_open, 0.0, "susunca ağız kapanır")


func test_voice_blip_does_not_break_in_a_headless_run() -> void:
	Feel.instant = false
	Feel.blip(0.3)
	Feel.blip(0.9)
	assert_true(true)
