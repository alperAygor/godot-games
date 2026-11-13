class_name ComebackSheet
extends RetentionSheet

## "Tekrar hoş geldin" / seri hediyesi sayfası: sıcak bir ikon, tek satır metin, ödül ve "Al".
## Bekleyen hediye `Comeback` durumundadır; alınca tek seferde verilir.

const CLAIM_HEIGHT: float = 132.0
const REWARD_FONT: int = 56
const SUN_ICON: String = "lucide/heart"

var _reward: Dictionary = {}


static func open(parent: Node) -> Node:
	var sheet: ComebackSheet = ComebackSheet.new()
	sheet._setup(parent)
	sheet._fill()
	sheet.play_intro()
	AnalyticsLog.record("ret_sheet_open", {"kind": "comeback"})
	return sheet


func _fill() -> void:
	var cfg: Dictionary = RetentionData.comeback()
	var state: Dictionary = RetentionFlow.comeback_state()
	var info: Dictionary = Comeback.pending(state)
	_reward = RetentionRewards.normalize(info.get("reward", {}))
	var away: int = int(info.get("away", 0))
	var streak: int = int(info.get("streak", 0))
	var comeback: bool = away > 0
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if comeback:
		holder.add_child(RetentionUi.disc(SUN_ICON, RetentionUi.WARM_SOFT, UiKit.FLAME, 112.0, 52.0))
	else:
		holder.add_child(RetentionUi.disc(RetentionUi.FLAME_ICON, RetentionUi.WARM_SOFT, UiKit.FLAME, 112.0, 52.0))
	content().add_child(holder)
	_add_gap(RetentionUi.GAP)
	_add_title(RetentionStrings.welcome_title() if comeback else RetentionStrings.streak_title(streak))
	_add_gap(RetentionUi.GAP * 0.4)
	var body: Label = UiKit.label(RetentionStrings.welcome_body(away) if comeback \
		else RetentionStrings.streak_body(), RetentionUi.BODY_SIZE, UiKit.TEXT_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content().add_child(body)
	_add_gap(RetentionUi.GAP * 1.3)
	var current: int = Comeback.streak_position(state, cfg)
	# Seri başlıkta zaten yazılı (streak kipi); alev satırı yalnız geri dönüşte seriyi hatırlatır.
	if current > 0 and comeback:
		content().add_child(RetentionUi.flame_row(current, 40))
		_add_gap(RetentionUi.GAP * 1.0)
	content().add_child(RetentionUi.reward_chips(_reward, REWARD_FONT))
	_add_gap(RetentionUi.GAP * 1.6)
	var claim: Button = UiKit.button(RetentionStrings.claim(), &"", RetentionUi.CHEST_ICON, CLAIM_HEIGHT)
	claim.pressed.connect(_on_claim.bind(claim))
	content().add_child(claim)


func _on_claim(button: Button) -> void:
	var reward: Dictionary = RetentionFlow.claim_comeback()
	if not reward.is_empty():
		_celebrate_at(button, reward)
	# Kutlama görünsün diye kısa gecikmeyle kapanır.
	get_tree().create_timer(0.7).timeout.connect(close)
	button.disabled = true
