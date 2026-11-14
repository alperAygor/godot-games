extends Control
## Ana menü. Sadece arayüz: kayıt işini GameSession yapar.
## Devam: kayıt varsa görünür. Yeni oyun: kayıt varsa önce onay sorar (kayıt silinir).

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _tagline: Label = $SafeArea/Content/Tagline

var _confirm: Control = null
var _guide: GuideSheet = null


func _ready() -> void:
	add_child(ScreenBackdrop.new())
	move_child(get_child(get_child_count() - 1), 1)  # arka plan panelinin hemen üstü
	var content: VBoxContainer = %Title.get_parent()
	content.add_child(MenuEmblem.new())
	content.move_child(content.get_child(content.get_child_count() - 1), 0)
	_build_mode_cards(content)
	_continue_button.visible = GameSession.has_save()
	if GameSession.has_save():
		_continue_button.text = tr("MENU_CONTINUE") % GameSession.saved_day()
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_setup_modes()
	if Monetization.consent_needed():
		add_child(ConsentSheet.new())
	var market: IconButton = %MarketButton
	market.text = tr("MENU_MARKET")
	market.pressed.connect(func() -> void: SceneManager.push(Scenes.MARKET))
	_settings_button.text = tr("MENU_SETTINGS")
	_settings_button.pressed.connect(_on_settings_pressed)
	var help: IconButton = %HelpButton
	help.text = tr("MENU_HELP")
	help.label_text = tr("MENU_HELP_SHORT")
	help.pressed.connect(_open_guide)
	print("[Main] hazır")


## İki ana mod: Hikaye kartı (devam/yeni oyun) ve Sonsuz düğmesi; Günün Kuru ve diğerleri alttaki ikon satırında.
func _build_mode_cards(content: VBoxContainer) -> void:
	var story := UiKit.card("", &"BoothHud", "StoryCard")
	var panel: Control = story.get_meta("panel")
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 14)
	heading.add_child(IconView.new("book", Color("FFC857"), 44.0))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(UiKit.label(tr("MENU_STORY"), &"BoothHeading", "StoryTitle"))
	texts.add_child(UiKit.label(tr("MENU_STORY_SUB"), &"BoothMuted", "StorySub"))
	heading.add_child(texts)
	story.add_child(heading)
	for button: Button in [_continue_button, _new_game_button]:
		button.get_parent().remove_child(button)
		button.custom_minimum_size.x = 0.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		story.add_child(button)
	panel.custom_minimum_size.x = 560.0
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(panel)
	content.move_child(panel, _tagline.get_index() + 2)
	var endless := UiKit.icon_button("infinity", tr("MENU_ENDLESS_PLAY"), "EndlessButton", true, true, 104.0)
	endless.custom_minimum_size.x = 560.0
	endless.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(endless)
	content.move_child(endless, panel.get_index() + 1)


## Günün Kuru ve Sonsuz: hikayede ilgili gün geçilince açılır; açıkken en iyi skoru gösterir.
func _setup_modes() -> void:
	var store := GameSession.modes()
	var daily: IconButton = %DailyButton
	var endless: IconButton = find_child("EndlessButton", true, false)
	daily.label_text = tr("MODE_DAILY_TITLE")
	if store.is_unlocked(ModeRun.KIND_DAILY):
		var date := DailyChallenge.date_key()
		var best := store.best_daily(date)
		var left := store.official_attempts_left(date)
		if left <= 0:
			daily.text = tr("MENU_DAILY_PRACTICE")
		else:
			daily.text = tr("MENU_DAILY_BEST") % best if best >= 0 else tr("MENU_DAILY_PLAY")
		daily.pressed.connect(func() -> void:
			GameSession.start_daily()
			SceneManager.goto(Scenes.DESK))
	else:
		daily.text = tr("MENU_DAILY_LOCKED")
		daily.disabled = true
		daily.locked = true
	if store.is_unlocked(ModeRun.KIND_ENDLESS):
		endless.text = tr("MENU_ENDLESS_BEST") % store.endless_best() if store.endless_best() > 0 else tr("MENU_ENDLESS_PLAY")
		endless.pressed.connect(func() -> void:
			GameSession.start_endless()
			SceneManager.goto(Scenes.DESK))
	else:
		endless.text = tr("MENU_ENDLESS_LOCKED")
		endless.disabled = true
		endless.locked = true


## Onay açıkken geri tuşu onu kapatır; yoksa uygulama kapanır (SceneManager).
func handle_back() -> bool:
	if _guide != null and is_instance_valid(_guide):
		return _guide.handle_back()
	if _confirm != null:
		_close_confirm()
		return true
	return false


func _on_continue_pressed() -> void:
	if GameSession.continue_game():
		SceneManager.goto(GameSession.route())


func _on_new_game_pressed() -> void:
	if GameSession.has_save():
		_open_confirm()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameSession.new_game()
	# İlk yeni oyunda önce rehber; bitince (ya da atlanınca) ilk sabah.
	if not bool(SettingsManager.get_value("game", "guide_seen")):
		_open_guide(func() -> void: SceneManager.goto(Scenes.MORNING))
		return
	SceneManager.goto(Scenes.MORNING)


func _open_guide(on_finished := Callable()) -> void:
	if _guide != null and is_instance_valid(_guide):
		return
	_guide = GuideSheet.new()
	if on_finished.is_valid():
		_guide.finished.connect(on_finished)
	add_child(_guide)


func _on_settings_pressed() -> void:
	SceneManager.push(Scenes.SETTINGS)


func _open_confirm() -> void:
	_confirm = Control.new()
	_confirm.name = "NewGameConfirm"
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = UiKit.DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var box := UiKit.card("", &"FloatCard")
	center.add_child(box.get_meta("panel"))
	box.add_child(UiKit.label(tr("MENU_NEW_CONFIRM_TITLE"), &"SheetTitle"))
	box.add_child(UiKit.wrapped(tr("MENU_NEW_CONFIRM_TEXT"), &"GoalLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var yes := UiKit.button(tr("COMMON_YES"), "ConfirmYesButton", &"RepairButton", 84.0)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_start_new_game)
	var no := UiKit.button(tr("COMMON_NO"), "ConfirmNoButton", &"GhostButton", 84.0)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_close_confirm)
	row.add_child(yes)
	row.add_child(no)


func _close_confirm() -> void:
	if _confirm != null:
		remove_child(_confirm)
		_confirm.queue_free()
		_confirm = null
