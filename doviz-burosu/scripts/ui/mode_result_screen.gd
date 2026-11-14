extends Control
## Günün Kuru / Sonsuz sonuç ekranı: puan, rekor, ayrıntı, paylaş (panoya kopyalar), tekrar oyna, ana menü.
## Sonuç GameSession.finish_mode()'un doldurduğu `mode_result` sözlüğünden gelir.

var _result: Dictionary
var _share_note: Label


func _ready() -> void:
	_result = GameSession.mode_result
	if _result.is_empty():
		UiKit.redirect_when_idle(get_tree(), Scenes.MAIN)
		return
	var daily := str(_result["kind"]) == ModeRun.KIND_DAILY
	var column := UiKit.screen_column(self, 14)
	column.add_child(_spacer())
	var title_text := tr("MODE_DAILY_TITLE") + " · " + DailyChallenge.short_date(str(_result["date"])) if daily else tr("MODE_ENDLESS_TITLE")
	column.add_child(_centered(UiKit.label(title_text, &"BoothHeading", "ModeTitle")))
	column.add_child(_centered(UiKit.label(str(_result["score"]), &"BoothTitle", "ModeScore")))
	if bool(_result["new_best"]) and bool(_result["official"]):
		column.add_child(_centered(UiKit.label(tr("MODE_NEW_BEST"), &"BoothHeading", "ModeNewBest")))
	column.add_child(_centered(UiKit.label(tr("MODE_BEST") % int(_result.get("best", 0)), &"BoothMuted", "ModeBest")))
	var detail := UiKit.card("", &"CardPanel", "ModeDetail")
	if daily:
		detail.add_child(UiKit.wrapped(tr("MODE_DAILY_DETAIL") % [int(_result["correct"]), int(_result["mistakes"]), int(_result["seconds_left"])], &"GoalLabel"))
		if not bool(_result["official"]):
			detail.add_child(UiKit.wrapped(tr("MODE_PRACTICE"), &"CardDetail", "PracticeNote"))
	else:
		detail.add_child(UiKit.wrapped(tr("MODE_ENDLESS_DETAIL") % int(_result["served"]), &"GoalLabel"))
		var names: PackedStringArray = []
		for rule_id: Variant in _result["rules_added"]:
			names.append(tr("RULE_%s" % rule_id))
		if not names.is_empty():
			detail.add_child(UiKit.wrapped(tr("MODE_RULES_ADDED") % ", ".join(names), &"CardDetail", "RulesAdded"))
	column.add_child(detail.get_meta("panel"))
	column.add_child(_spacer())
	_share_note = UiKit.label("", &"BoothMuted", "ShareDone")
	_share_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_share_note)
	if daily and bool(_result["official"]):
		var share := UiKit.icon_button("share", tr("MODE_SHARE"), "ShareButton", true, false, 88.0)
		share.pressed.connect(_share)
		column.add_child(share)
	if daily and int(_result["attempts_left"]) <= 0:
		var offer := Monetization.rewarded_offer("daily_retry", GameSession.modes().bonus_granted(str(_result["date"])))
		if bool(offer["visible"]):
			var retry := UiKit.icon_button("ad", tr("AD_DAILY_RETRY") if bool(offer["enabled"]) else tr("AD_UNAVAILABLE"), "DailyRetryButton", true, false, 88.0)
			retry.disabled = not bool(offer["enabled"])
			retry.pressed.connect(_ad_retry.bind(retry))
			column.add_child(retry)
	var replay_text := tr("MODE_NEW_RUN")
	if daily:
		replay_text = tr("MODE_REPLAY") if int(_result["attempts_left"]) > 0 else tr("MODE_PRACTICE_BUTTON")
	var replay := UiKit.button(replay_text, "ReplayButton", &"", 88.0)
	replay.pressed.connect(_replay.bind(daily))
	column.add_child(replay)
	var menu := UiKit.button(tr("END_MENU"), "MenuButton", &"GhostButton", 88.0)
	menu.pressed.connect(_to_menu)
	column.add_child(menu)
	print("[ModeResult] %s puan %d" % [_result["kind"], int(_result["score"])])
	Monetization.count_play_unit()
	Monetization.show_interstitial_then("mode_end", func() -> void: pass)


func handle_back() -> bool:
	_to_menu()
	return true


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _share() -> void:
	var language := "tr" if TranslationServer.get_locale().begins_with("tr") else "en"
	DisplayServer.clipboard_set(DailyChallenge.share_text(str(_result["date"]), int(_result["score"]), language))
	_share_note.text = tr("MODE_COPIED")


func _ad_retry(button: Button) -> void:
	button.disabled = true
	Monetization.request_reward("daily_retry", func(rewarded: bool) -> void:
		if not is_inside_tree():
			return
		if rewarded:
			GameSession.modes().grant_bonus_attempt(str(_result["date"]))
			_replay(true)
		else:
			button.disabled = false)


func _replay(daily: bool) -> void:
	if daily:
		GameSession.start_daily(str(_result["date"]))
	else:
		GameSession.start_endless()
	SceneManager.goto(Scenes.DESK)


func _to_menu() -> void:
	GameSession.abort_mode()
	SceneManager.goto(Scenes.MAIN)
