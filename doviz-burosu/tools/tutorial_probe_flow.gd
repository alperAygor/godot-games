extends RefCounted
## Gün 1 öğretici sondasının akışı (`tools/tutorial_probe.gd` ve `test_tutorial` çağırır).

const TouchInput := preload("res://tools/touch_input.gd")
const MAX_ROUNDS := 2000
## Ders sonrası her müşteride harcanan oyun süresi (sn): Gün 1'de ~13-15 müşteri eder.
const PLAYER_SECONDS := 15.0


## Akışı oynar; dönen: {ok, reason, steps (görülen adımlar sırasıyla), served, correct, mistakes, first_correct}.
static func play_first_day(tree: SceneTree) -> Dictionary:
	var scenes := tree.root.get_node("SceneManager")
	var session := tree.root.get_node("GameSession")
	DeskTutorial.write_state(false, false)
	session.story_enabled = true
	session.new_game()
	await scenes.goto(Scenes.MORNING)
	await tree.process_frame
	var report := {"ok": false, "reason": "", "steps": [], "served": 0, "correct": 0, "mistakes": 0, "first_correct": false}
	if not await TouchInput.tap_node(tree, "StartShiftButton"):
		report["reason"] = "StartShiftButton yok"
		return report
	for i in 40:
		if scenes.current_path() == Scenes.DESK:
			break
		await tree.process_frame
	var desk := tree.current_scene as DeskScreen
	if desk == null or desk.tutorial == null:
		report["reason"] = "masa ya da öğretici kurulmadı"
		return report
	desk.set_process(false)
	var steps: Array = report["steps"]
	for round_index in MAX_ROUNDS:
		await tree.process_frame
		if TouchInput.find_control(tree, "ToEveningButton") != null:
			break
		var story := TouchInput.find_control(tree, "StorySheet")
		if story != null:
			if not await TouchInput.tap_node(tree, "StoryContinueButton"):
				for child in story.find_children("StoryOption_*", "Button", true, false):
					if not (child as Button).disabled:
						await TouchInput.tap_node(tree, child.name)
						break
			continue
		var step := desk.tutorial.flow.current() if not desk.tutorial.flow.is_done() else TutorialFlow.STEP_DONE
		if step not in [TutorialFlow.STEP_WAITING, TutorialFlow.STEP_DONE, TutorialFlow.STEP_HIDDEN]:
			if steps.is_empty() or steps[-1] != step:
				steps.append(step)
			if not await _do_step(tree, desk, step):
				report["reason"] = "adım yapılamadı: %s" % step
				return report
			if step == TutorialFlow.STEP_STAMP:  # damga anında işlenir: ders müşterisi ilk müşteridir
				report["first_correct"] = int(desk.shift.stats["served"]) == 1 and int(desk.shift.stats["correct"]) == 1
			continue
		if desk.shift.current != null and desk._shown != null and desk.model != null:
			desk.tick(PLAYER_SECONDS)  # oyuncu gibi zaman harcar (yoksa yüzlerce müşteri gelir, kasa biter)
			if desk.model != null and desk.shift.current != null:
				_serve_perfectly(desk)
			continue
		desk.tick(1.0)
	report["served"] = int(desk.shift.stats["served"])
	report["correct"] = int(desk.shift.stats["correct"])
	report["mistakes"] = int(desk.shift.stats["mistake_transactions"])
	if TouchInput.find_control(tree, "ToEveningButton") == null:
		report["reason"] = "mesai bitmedi"
	elif not desk.tutorial.flow.is_done() or desk.tutorial.flow.skipped:
		report["reason"] = "öğretici tamamlanmadı"
	elif steps != TutorialFlow.ORDER:
		report["reason"] = "adım sırası beklenenden farklı"
	elif not bool(report["first_correct"]) or int(report["mistakes"]) != 0:
		report["reason"] = "ilk müşteri/gün hatalı"
	else:
		report["ok"] = true
	return report


## Öğreticinin istediği eylemi yapar (oyuncu gibi, dokunarak).
static func _do_step(tree: SceneTree, desk: DeskScreen, step: String) -> bool:
	match step:
		TutorialFlow.STEP_REQUEST, TutorialFlow.STEP_RESULT, TutorialFlow.STEP_OUTRO:
			return await TouchInput.tap_node(tree, "TutorialNext")
		TutorialFlow.STEP_INSPECT:
			return await TouchInput.tap_node(tree, "NoteTile0")
		TutorialFlow.STEP_INSPECT_CLOSE, TutorialFlow.STEP_RATES_CLOSE, TutorialFlow.STEP_CLOSE_OTHER:
			return await TouchInput.tap_node(tree, "CloseSheetButton")
		TutorialFlow.STEP_RATES:
			return await TouchInput.tap_node(tree, "ToolBookButton")
		TutorialFlow.STEP_PAY:
			return await TouchInput.tap_node(tree, "PayButton_%s" % str(desk.tutorial.flow.lesson["local"]))
		TutorialFlow.STEP_PAY_TYPE:
			var units := int(desk.tutorial.flow.lesson["payout_minor"]) / Money.UNIT
			for digit in str(units):
				if not await TouchInput.tap_node(tree, "Key_%s" % digit):
					return false
			return await TouchInput.tap_node(tree, "NumpadOk")
		TutorialFlow.STEP_STAMP:
			return await TouchInput.tap_node(tree, "CompleteButton")
	return false


## Günün kalan müşterileri: motorun doğru cevabı (banknot kaderleri, ödeme, karar).
static func _serve_perfectly(desk: DeskScreen) -> void:
	var verdict := desk.shift.current_verdict
	for i in verdict.fates.size():
		desk.model.set_fate(i, verdict.fates[i])
	for code: String in verdict.pay_out:
		desk.model.set_paid(code, int(verdict.pay_out[code]))
	desk._decide(verdict.decision, verdict.reasons[0] if not verdict.reasons.is_empty() else "")
