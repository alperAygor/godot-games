class_name DeskFeedback
extends RefCounted
## Karar anının "hissi": fişe mühür, ekrana damga, sarsıntı, ses, titreşim, (doğruysa) kazanç yazısı ve para patlaması.

const DECISION_COLORS := {
	Verdict.DECISION_COMPLETE: UiKit.GOOD_COLOR,
	Verdict.DECISION_REJECT: UiKit.WARN_COLOR,
	Verdict.DECISION_POLICE: UiKit.BAD_COLOR,
}


static func play(desk: DeskScreen, decision: String, result: Dictionary) -> void:
	desk.counter.ink_receipt(decision)
	var color: Color = DECISION_COLORS[decision]
	Feel.stamp(desk, TranslationServer.translate("STAMP_%s" % decision.to_upper()), color)
	var correct := bool(result["correct"])
	Feel.shake(desk, 4.0 if correct else 8.0)
	Feel.sfx("stamp")
	var tree := desk.get_tree()
	tree.create_timer(0.05).timeout.connect(Feel.sfx.bind("ink_press"))
	if decision == Verdict.DECISION_POLICE:
		tree.create_timer(0.25).timeout.connect(Feel.sfx.bind("siren"))
	elif decision == Verdict.DECISION_COMPLETE and correct:
		tree.create_timer(0.3).timeout.connect(Feel.sfx.bind("drawer"))
	Feel.haptic(25 if correct else 70)
	Fx.splat(desk, desk.size / 2.0, color)
	var pay_label := desk.hud.pay_label
	if correct:
		Fx.coin_burst(desk, pay_label.global_position + Vector2(40, 30), 7)
		Feel.float_text(desk, "+" + UiKit.money(int(result["bonus_minor"]), "PL"), UiKit.GOOD_COLOR, pay_label.global_position + Vector2(0, 40))
		tree.create_timer(0.12).timeout.connect(Feel.sfx.bind("coin"))
	else:
		Fx.flash(desk, UiKit.BAD_COLOR, 0.3 if bool(result["fined"]) else 0.18)
		tree.create_timer(0.12).timeout.connect(Feel.sfx.bind("error"))
