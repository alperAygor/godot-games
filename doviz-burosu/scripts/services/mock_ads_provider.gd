class_name MockAdsProvider
extends AdsProvider
## Geliştirme ve test için sahte reklam: ödüllü reklam hep hazır. Varsayılan hemen ödül verir (testler).
## `interactive` açıkken ekranda SAHTE bir reklam penceresi çıkar ("Ödülü al" / "İptal"); Monetization bunu açık ekranda açar.

var interactive := false
## Testlerde bir sonraki ödüllü reklamı iptal ettirmek için (ödül verilmez).
var cancel_next := false
var ready_state := true


func is_rewarded_ready(_placement: String) -> bool:
	return ready_state


func show_rewarded(placement: String) -> void:
	if interactive and _open_overlay("Ödüllü reklam: %s" % placement, true, func(rewarded: bool) -> void: rewarded_finished.emit(placement, rewarded)):
		return
	var rewarded := not cancel_next
	cancel_next = false
	rewarded_finished.emit.call_deferred(placement, rewarded)


func show_interstitial(placement: String) -> void:
	if interactive and _open_overlay("Geçiş reklamı: %s" % placement, false, func(_rewarded: bool) -> void: interstitial_closed.emit(placement)):
		return
	interstitial_closed.emit.call_deferred(placement)


func _open_overlay(title: String, rewarded: bool, done: Callable) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var overlay := FakeAd.new()
	tree.root.add_child(overlay)
	overlay.setup(title, rewarded)
	overlay.finished.connect(done)
	return true
