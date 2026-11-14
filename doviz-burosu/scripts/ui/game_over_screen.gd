extends Control
## Oyunun sonu: 15. gün bittiğinde bayraklara göre bir son (Endings), ya da oyun içi bitiş (kovuldun, tutuklandın...).
## Oyun içi bitişte sabah anlık görüntüsü varsa "Günü tekrar oyna" sunulur (Faz 10'da arkasına ödüllü reklam gelecek).
## Görülen sonlar kayıttan bağımsız tutulur ve burada sayılır.


func _ready() -> void:
	if GameSession.career == null and not GameSession.continue_game():
		UiKit.redirect_when_idle(get_tree(), Scenes.MAIN)
		return
	var career := GameSession.career
	var db := StoryDb.load_default()
	var ending := Endings.resolve(career, db)
	var over := career.is_over()
	if not ending.is_empty():
		GameSession.record_ending(str(ending["id"]))
		Analytics.log_event("ending", {"id": ending["id"]})
	AudioManager.play_track(_ending_track(str(ending.get("id", ""))), 2.0)
	if over:
		Feel.sfx("chime_fail")
	else:
		Feel.sfx("stinger_win")
		if _ending_track(str(ending.get("id", ""))) == "ending_warm":
			Fx.confetti(self)
	var column := UiKit.screen_column(self, 16)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var title := UiKit.label(tr(str(ending.get("title_key", "GAMEOVER_TITLE"))), &"BoothTitle", "GameOverTitle")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var body := tr(str(ending["body_key"])) if not ending.is_empty() else ""
	if over:
		body += "\n\n" + tr("END_OVER_%s" % career.game_over.to_upper())
	var message := UiKit.wrapped(body, &"BoothBody", "GameOverMessage")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)
	var seen := UiKit.label(tr("ENDING_COUNT") % [GameSession.endings_seen().size(), Endings.all_ids(db).size()], &"BoothMuted", "EndingCount")
	seen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(seen)
	var spacer_two := Control.new()
	spacer_two.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer_two)
	if over and not career.morning_snapshot.is_empty():
		var offer := Monetization.rewarded_offer("retry_day", 0)
		var retry := UiKit.icon_button("ad", tr("AD_RETRY_DAY") if bool(offer["enabled"]) else tr("AD_UNAVAILABLE"), "RetryDayButton", true, false, 96.0)
		retry.disabled = not bool(offer["enabled"])
		retry.pressed.connect(func() -> void:
			retry.disabled = true
			Monetization.request_reward("retry_day", func(rewarded: bool) -> void:
				if rewarded and is_inside_tree():
					_retry_day()
				elif is_inside_tree():
					retry.disabled = false))
		column.add_child(retry)
	var again := UiKit.button(tr("MENU_NEW_GAME"), "NewGameButton", &"WarnButton", 96.0)
	again.pressed.connect(func() -> void:
		GameSession.new_game()
		SceneManager.goto(Scenes.MORNING))
	column.add_child(again)
	var menu := UiKit.button(tr("END_MENU"), "MenuButton", &"GhostButton", 96.0)
	menu.pressed.connect(func() -> void: SceneManager.goto(Scenes.MAIN))
	column.add_child(menu)
	print("[GameOver] son: %s%s" % [ending.get("id", "-"), " (oyun içi: %s)" % career.game_over if over else ""])


## Sonun havasına göre müzik: sıcak (dürüst, merhametli, muhbir), kaçış, koyu (kovulma, tutuklanma, gri).
static func _ending_track(ending_id: String) -> String:
	if ending_id in ["honest", "mercy", "informant"]:
		return "ending_warm"
	if ending_id == "escape":
		return "ending_escape"
	return "ending_dark"


func handle_back() -> bool:
	SceneManager.goto(Scenes.MAIN)
	return true


func _retry_day() -> void:
	if GameSession.career.restore_morning():
		GameSession.save()
		SceneManager.goto(Scenes.MORNING)
