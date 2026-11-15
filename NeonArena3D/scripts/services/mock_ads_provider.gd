class_name MockAdsProvider
extends AdsProvider
## Geliştirme/test sağlayıcısı: gerçek SDK yokken reklam akışını uçtan uca sınar. Sonuç ayarlanabilir
## (başarı, erken kapatma, doluluk yok, zaman aşımı); rastgelelik YOK, her koşu belirleyicidir.
## `delay_seconds == 0` -> eşzamanlı (birim testler); > 0 -> süreyi sahne zamanlayıcısıyla bekler (masaüstü).

enum Outcome { SUCCESS, DISMISSED, NO_FILL, TIMEOUT }

const DEFAULT_DELAY: float = 1.2

## show() sonucu. SUCCESS: shown + (ödüllü: rewarded | geçiş: dismissed). DISMISSED: shown, ödüllüde "dismissed_early"
## (ödül yok), geçişte normal kapanış. NO_FILL: shown olmadan failed("no_fill"). TIMEOUT: hiçbir şey yayılmaz.
var outcome: Outcome = Outcome.SUCCESS
var delay_seconds: float = DEFAULT_DELAY
var ready: bool = true
## Onay: true -> hemen çözülür; false -> `resolve_consent()` çağrılana dek bekler (UMP formu açık gibi).
var consent_instant: bool = true
var consent_can_request: bool = true
var privacy_required: bool = false
var show_count: int = 0
var initialized: bool = false
var privacy_shown_count: int = 0

var _pending_consent: Callable = Callable()


func request_consent(on_done: Callable) -> void:
	if consent_instant:
		on_done.call(consent_can_request)
	else:
		_pending_consent = on_done


## Test/probe yardımcısı: bekleyen onay akışını bitirir.
func resolve_consent(can_request: bool = true) -> void:
	if _pending_consent.is_valid():
		var cb: Callable = _pending_consent
		_pending_consent = Callable()
		cb.call(can_request)


func privacy_options_required() -> bool:
	return privacy_required


func show_privacy_options(on_done: Callable) -> void:
	privacy_shown_count += 1
	on_done.call()


func initialize() -> void:
	initialized = true


func is_ready(_placement: int) -> bool:
	return ready


func show(placement: int) -> void:
	show_count += 1
	if outcome == Outcome.TIMEOUT:
		return
	if outcome == Outcome.NO_FILL:
		_run(func() -> void: failed.emit("no_fill"))
		return
	shown.emit()
	_run(_finish.bind(placement))


func _run(action: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if delay_seconds <= 0.0 or tree == null:
		action.call()
		return
	# process_always = true: sahne duraklatılmış olsa da reklam akışı ilerlesin.
	tree.create_timer(delay_seconds, true, false, true).timeout.connect(action)


func _finish(placement: int) -> void:
	if placement == INTERSTITIAL_PLACEMENT:
		dismissed.emit()
	elif outcome == Outcome.DISMISSED:
		failed.emit("dismissed_early")
	else:
		rewarded.emit()
