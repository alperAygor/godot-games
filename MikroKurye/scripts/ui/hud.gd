class_name Hud
extends CanvasLayer

## HUD yalnızca gösterir: GameController her fizik karesinde 0..100 yüzdeyi
## `set_*` ile iter. Hesap `scripts/core/` sınıflarındadır (ARCHITECTURE §6).
## Revive/hızlı şarj düğmeleri de karar vermez; niyeti sinyalle GameController'a
## iletir (reklam ve ödül akışı orada yönetilir).

const MIN_PERCENT: float = 0.0
const MAX_PERCENT: float = 100.0

signal revive_accepted()
signal revive_declined()
signal recharge_requested()

@onready var _cargo_bar: ProgressBar = $Root/TopPanel/Bars/CargoHealthBar
@onready var _battery_bar: ProgressBar = $Root/TopPanel/Bars/BatteryBar
@onready var _revive_panel: Control = $Root/RevivePanel
@onready var _revive_title: Label = $Root/RevivePanel/Column/ReviveTitle
@onready var _revive_text: Label = $Root/RevivePanel/Column/ReviveText
@onready var _revive_button: Button = $Root/RevivePanel/Column/ReviveButton
@onready var _decline_button: Button = $Root/RevivePanel/Column/DeclineButton
@onready var _recharge_button: Button = $Root/RechargeButton


func _ready() -> void:
	# Metinler tek yerde (strings.gd); sahne yalnızca yerleşim taşır.
	_revive_title.text = UiStrings.REVIVE_TITLE
	_revive_text.text = UiStrings.REVIVE_TEXT
	_revive_button.text = UiStrings.REVIVE_ACCEPT
	_decline_button.text = UiStrings.REVIVE_DECLINE
	_recharge_button.text = UiStrings.RECHARGE
	_recharge_button.tooltip_text = UiStrings.RECHARGE_HINT
	_revive_panel.visible = false
	_recharge_button.visible = false
	_revive_button.pressed.connect(func() -> void: revive_accepted.emit())
	_decline_button.pressed.connect(func() -> void: revive_declined.emit())
	_recharge_button.pressed.connect(func() -> void: recharge_requested.emit())


func set_cargo_health(percent: float) -> void:
	_cargo_bar.value = clampf(percent, MIN_PERCENT, MAX_PERCENT)


func set_battery(percent: float) -> void:
	_battery_bar.value = clampf(percent, MIN_PERCENT, MAX_PERCENT)


func set_revive_offered(offered: bool) -> void:
	_revive_panel.visible = offered


func set_ad_pending(pending: bool) -> void:
	_revive_button.disabled = pending
	_decline_button.disabled = pending
	_recharge_button.disabled = pending


func set_recharge_available(available: bool) -> void:
	_recharge_button.visible = available
