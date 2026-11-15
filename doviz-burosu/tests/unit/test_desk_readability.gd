extends "res://tests/session_case.gd"
## Masa telefonda okunur ve tek elle kullanılır: en küçük yazı eşiği, dokunma hedefi yükseklikleri, damgalar en altta
## (başparmak), sayfalar güvenli alanın içinde, dokunuşa 100 ms içinde görünür tepki.

## Tasarım pikseli (720 genişlik). VT323 küçük durduğu için eşik tema `SlipLine`/`GoalLabel` boyutudur (29).
const MIN_TEXT := 29
## Birincil dokunma hedefleri (damga, ödeme, araç, sayfa düğmeleri): ~48 dp.
const MIN_PRIMARY := 88.0
## Gişe köşesindeki küçük kısayollar (ofis, iğnelenen notlar) daha alçak olabilir ama bundan az değil.
const MIN_SECONDARY := 64.0
const SECONDARY := ["OfficeButton", "OvertimeButton"]

var desk: DeskScreen


func _open(day := 1) -> void:
	var career := Career.load_default("readability")
	career.day = day
	for tool_id in ["uv", "magnifier", "rate_calc", "counter"]:
		career.tools.append(tool_id)
	session.career = career
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene as DeskScreen
	desk.set_process(false)
	await tree.process_frame
	await tree.process_frame


func _outside_sheets(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null and parent != desk:
		if parent.name == "Sheet" or parent.name == "Tutorial":
			return false
		parent = parent.get_parent()
	return true


func test_no_desk_text_is_smaller_than_the_threshold() -> void:
	for day in [1, 12]:
		await _open(day)
		if day == 12:  # belgeli müşteri: kimlik + beyan kâğıtları da tezgâhta
			var customer := seller("FED", [100, 50], day)
			give_id(customer, desk.shift.ctx)
			give_declaration(customer, desk.shift.ctx)
			desk.shift.current = customer
			desk.shift.current_verdict = RuleEngine.new(desk.shift.ctx).evaluate(customer)
			desk.tick(0.0)
			await tree.process_frame
			assert_true(node("DocTile_id") != null, "kimlik kâğıdı masada")
		var checked := 0
		for label: Label in desk.find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.strip_edges().is_empty() or not _outside_sheets(label):
				continue
			checked += 1
			assert_true(label.get_theme_font_size("font_size") >= MIN_TEXT,
				"gün %d: '%s' (%s) %d px" % [day, label.text, label.name, label.get_theme_font_size("font_size")])
		assert_true(checked >= 6, "gün %d: %d yazı denetlendi" % [day, checked])


func test_touch_targets_are_tall_enough() -> void:
	await _open(12)
	for button: Button in desk.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree() or not _outside_sheets(button):
			continue
		var minimum := MIN_SECONDARY if button.name in SECONDARY or str(button.name).begins_with("Pinned_") else MIN_PRIMARY
		assert_true(button.size.y >= minimum, "%s yüksekliği %.0f < %.0f" % [button.name, button.size.y, minimum])


func test_sheet_buttons_are_tall_enough() -> void:
	await _open(12)
	for opener in ["PayButton_PL", "ToolBookButton", "ToolCalcButton", "ToolCatalogButton", "ToolRateButton", "NoteTile0"]:
		await tap(opener)
		assert_true(desk.sheets.is_open(), opener)
		for button: Button in desk.sheets.sheet.find_children("*", "Button", true, false):
			if button.is_visible_in_tree():
				assert_true(button.size.y >= MIN_PRIMARY, "%s sayfası: %s %.0f" % [opener, button.name, button.size.y])
		desk.sheets.close()
		await tree.process_frame


func test_the_stamps_sit_at_the_bottom_within_thumb_reach() -> void:
	await _open()
	var screen := desk.get_rect().size
	for name in ["CompleteButton", "RejectButton", "PoliceButton"]:
		var rect := node(name).get_global_rect()
		assert_true(rect.position.y > screen.y * 0.8, "%s alt beşte birde" % name)
		assert_true(rect.size.y >= 128.0)
	assert_true(node("PayButton_PL").get_global_rect().position.y > screen.y * 0.6, "ödeme alanı alt yarıda")


func test_a_note_tap_opens_the_inspect_page_at_once() -> void:
	await _open()
	var started := Time.get_ticks_msec()
	await tap("NoteTile0")
	assert_true(node("InspectView") != null)
	# dokunuş (50 ms basılı) + iki kare: sayfa aynı karede açılır
	assert_true(Time.get_ticks_msec() - started < 400, "inceleme gecikmesiz")


func test_a_stamp_moves_within_100_ms_of_the_touch() -> void:
	Feel.instant = false
	await _open()
	var stamp := node("CompleteButton")
	var started := Time.get_ticks_msec()
	(stamp as Button).emit_signal("pressed")
	await tree.process_frame
	await tree.process_frame
	assert_true(stamp.scale != Vector2.ONE, "damga hemen kalkar (görsel tepki)")
	assert_true(Time.get_ticks_msec() - started < 100, "tepki 100 ms içinde")
	await tree.create_timer(0.4).timeout
	Feel.instant = true
