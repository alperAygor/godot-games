class_name DeskFlowSheets
extends RefCounted
## Vardiyanın akışını kesen sayfalar: hikaye olayı ("StorySheet"), duraklatma ve mesai bitti / mod bitti.

var desk: DeskScreen
var _story_db: StoryDb


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk


## Hikaye olayı: konuşan karakter, söyledikleri ve (varsa) seçenekler. Vardiya durur; kapatılamaz, bir seçim ya da "Devam" gerekir.
func open_story(beat: Dictionary) -> void:
	if _story_db == null:
		_story_db = StoryDb.load_default()
	var character := _story_db.character(str(beat["character"]))
	var sheets := desk.sheets
	var content := sheets.open("", false)
	sheets.rename("StorySheet")
	sheets.pauses = true
	sheets.set_title(content, tr(str(character.get("name_key", "CHAR_RIZA"))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	if character.has("icon"):  # yüzü olmayan konuşmacı (radyo)
		var badge := CenterContainer.new()
		badge.custom_minimum_size = Vector2(110, 110)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		badge.add_child(IconView.new(str(character["icon"]), Color("C8892B"), 84.0))
		row.add_child(badge)
	else:
		var face := FaceView.new()
		face.caption = false
		face.setup(int(character.get("face_id", 0)), str(character.get("holder_name", "?")), 110.0)
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(face)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 8)
	row.add_child(lines)
	var index := 0
	for line_key: Variant in beat["lines"]:
		index += 1
		var line := UiKit.label(tr(str(line_key)), &"", "StoryLine%d" % index)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lines.add_child(line)
	var shift := desk.shift
	if shift.director.has_choice(beat):
		for option in shift.director.options(beat):
			var text := tr(str(option["text"]))
			if not option["available"]:
				text += "  " + tr("STORY_LOCKED")
			var tempting: bool = option["tag"] in ["bribe", "skim"]
			var button := UiKit.button(text, "StoryOption_%s" % option["id"], &"WarnButton" if tempting else &"", 88.0)
			button.disabled = not option["available"]
			button.pressed.connect(_on_story_choice.bind(str(option["id"])))
			content.add_child(button)
	else:
		var next := UiKit.button(tr("STORY_OK"), "StoryContinueButton", &"", 88.0)
		next.pressed.connect(_on_story_choice.bind(""))
		content.add_child(next)


func _on_story_choice(option_id: String) -> void:
	if desk.shift.resolve_beat(option_id):
		desk.sheets.close()
		desk._sync()


func open_pause() -> void:
	var content := desk.sheets.open("PAUSE_TITLE")
	desk.sheets.pauses = true
	var resume := UiKit.button(tr("PAUSE_RESUME"), "ResumeButton", &"", 96.0)
	resume.pressed.connect(desk.sheets.close)
	content.add_child(resume)
	var menu := UiKit.button(tr("PAUSE_MENU"), "PauseMenuButton", &"GhostButton", 96.0)
	menu.pressed.connect(func() -> void:
		GameSession.abort_mode()
		SceneManager.goto(Scenes.MAIN))
	content.add_child(menu)


## Mesai bitti: özet akşam ekranında; burada son uyarı fişini okumaya zaman bırakır.
func open_day_end() -> void:
	var content := desk.sheets.open("MODE_RUN_OVER" if GameSession.mode is EndlessRun else "DESK_SHIFT_OVER", false)
	if GameSession.mode is EndlessRun:
		var endless := GameSession.mode as EndlessRun
		var offer := Monetization.rewarded_offer("endless_continue", endless.continues_used)
		if bool(offer["visible"]):
			var more := UiKit.button(tr("AD_ENDLESS_CONTINUE") if bool(offer["enabled"]) else tr("AD_UNAVAILABLE"), "EndlessContinueButton", &"InkButton", 96.0)
			more.disabled = not bool(offer["enabled"])
			more.pressed.connect(desk._request_endless_continue)
			content.add_child(more)
	elif GameSession.mode == null:
		var overtime := desk._overtime_offer()
		if bool(overtime["visible"]):
			var extend := UiKit.button(tr("AD_OVERTIME") if bool(overtime["enabled"]) else tr("AD_UNAVAILABLE"), "OvertimeEndButton", &"InkButton", 96.0)
			extend.disabled = not bool(overtime["enabled"])
			extend.pressed.connect(desk._request_overtime)
			content.add_child(extend)
	if GameSession.mode != null:
		var result_button := UiKit.button(tr("MODE_SEE_RESULT"), "ToResultButton", &"", 96.0)
		result_button.pressed.connect(func() -> void:
			GameSession.finish_mode()
			SceneManager.goto(Scenes.MODE_RESULT))
		content.add_child(result_button)
		return
	var next := UiKit.button(tr("DESK_TO_EVENING"), "ToEveningButton", &"", 96.0)
	next.pressed.connect(func() -> void:
		GameSession.shift = desk.shift
		SceneManager.goto(Scenes.EVENING))
	content.add_child(next)
