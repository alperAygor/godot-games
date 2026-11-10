class_name HUD
extends CanvasLayer

## Sadece gösterir: buton basımlarını sinyal olarak yayar, kurallara karışmaz.
## Sahne duraklatıldığında da çalışır (process_mode = ALWAYS), aksi hâlde
## hata ekranındaki butonlar donar.

signal start_pressed()
signal extra_pocket_pressed()
signal tape_pressed()
signal revive_pressed()
signal retry_pressed()

@onready var title_label: Label = %Title
@onready var status_label: Label = %Status
@onready var shake_bar: ProgressBar = %ShakeBar
@onready var start_button: Button = %StartButton
@onready var extra_button: Button = %ExtraPocketButton
@onready var tape_button: Button = %TapeButton
@onready var fail_overlay: Control = %FailOverlay
@onready var fail_title: Label = %FailTitle
@onready var fail_desc: Label = %FailDesc
@onready var revive_button: Button = %ReviveButton
@onready var retry_button: Button = %RetryButton
@onready var ad_overlay: Control = %AdOverlay
@onready var toast_label: Label = %Toast

var _toast_tween: Tween = null


func _ready() -> void:
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	extra_button.pressed.connect(func() -> void: extra_pocket_pressed.emit())
	tape_button.pressed.connect(func() -> void: tape_pressed.emit())
	revive_button.pressed.connect(func() -> void: revive_pressed.emit())
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	fail_overlay.visible = false
	ad_overlay.visible = false
	toast_label.modulate.a = 0.0
	shake_bar.value = 0.0


func set_status(text: String) -> void:
	status_label.text = text


func set_shake_bar(intensity: float) -> void:
	shake_bar.value = clampf(intensity * 100.0, 0.0, 100.0)


func set_buttons(start_ok: bool, extra_ok: bool, tape_ok: bool) -> void:
	start_button.disabled = not start_ok
	extra_button.disabled = not extra_ok
	tape_button.disabled = not tape_ok


func show_fail(reason_text: String) -> void:
	fail_desc.text = reason_text
	fail_overlay.visible = true
	revive_button.disabled = not AdManager.can_offer(AdManager.Placement.TAPE_RESCUE)
	fail_overlay.modulate.a = 0.0
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fail_overlay, "modulate:a", 1.0, 0.22)


func hide_fail() -> void:
	fail_overlay.visible = false


func show_success() -> void:
	toast("Harika! Tüm paketler sağ salim teslim edildi")


func show_ad_overlay(visible_now: bool) -> void:
	ad_overlay.visible = visible_now


func toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
