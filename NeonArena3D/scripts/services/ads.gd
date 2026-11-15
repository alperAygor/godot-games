class_name Ads
extends RefCounted
## Oyun/menü kodunun KULLANDIĞI küçük, tipli cephe. SDK'yı, sağlayıcıyı, autoload'ı görmez; AdManager yoksa/sağlayıcı yoksa
## her çağrı güvenli no-op'tur (düğmeler gizli, akış sürer). Ayrıntı: docs/MONETIZATION.md.
##
##   if Ads.can_show(AdPlacement.Id.REVIVE): düğmeyi göster
##   Ads.show_rewarded(AdPlacement.Id.REVIVE, _do_revive)          # _do_revive YALNIZ ödül onaylanınca çağrılır
##   Ads.maybe_interstitial({"died": true}, _go_next)               # _go_next her durumda tam bir kez çağrılır

const MANAGER_NAME: String = "AdManager"

## Testler/probeler için: autoload yerine bu yöneticiyi kullan.
static var manager_override: Node = null
## Testler için: true iken yönetici yokmuş gibi davranılır (güvenli no-op yolu).
static var suppress_manager: bool = false


static func _manager() -> Node:
	if suppress_manager:
		return null
	if manager_override != null and is_instance_valid(manager_override):
		return manager_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(MANAGER_NAME) if tree != null else null


## Yöneticinin kendisi (sinyallere bağlanmak için: ad_started / rewarded_finished / availability_changed); yoksa null.
static func manager() -> Node:
	return _manager()


static func available() -> bool:
	return _manager() != null


## Yerleşim şu an sunulabilir mi (düğme gösterilsin mi)?
static func can_show(placement: AdPlacement.Id) -> bool:
	var m: Node = _manager()
	return m != null and bool(m.call("can_show", int(placement)))


## Ödüllü reklam. `on_reward` yalnız sağlayıcı ödülü onaylayınca; başarısızlıkta `on_fail(reason: String)` (isteğe bağlı).
## Dönüş: başladı mı.
static func show_rewarded(placement: AdPlacement.Id, on_reward: Callable, on_fail: Callable = Callable()) -> bool:
	var m: Node = _manager()
	if m == null:
		if on_fail.is_valid():
			on_fail.call("no_manager")
		return false
	return bool(m.call("show_rewarded", int(placement), on_reward, on_fail))


## Koşu bitince (Settings.record_run sonrası) bir kez. `then` HER DURUMDA tam bir kez çağrılır. Dönüş: reklam başladı mı.
static func maybe_interstitial(after_run_context: Dictionary, then: Callable) -> bool:
	var m: Node = _manager()
	if m == null:
		if then.is_valid():
			then.call()
		return false
	return bool(m.call("maybe_interstitial", after_run_context, then))


## Yeni koşu başında (koşu limitlerini ve "ödüllü izlendi" işaretini sıfırlar).
static func begin_run() -> void:
	var m: Node = _manager()
	if m != null:
		m.call("begin_run")


static func daily_bonus_available() -> bool:
	return can_show(AdPlacement.Id.DAILY_BONUS)


static func privacy_options_required() -> bool:
	var m: Node = _manager()
	return m != null and bool(m.call("privacy_options_required"))


static func show_privacy_options(on_done: Callable = Callable()) -> void:
	var m: Node = _manager()
	if m == null:
		if on_done.is_valid():
			on_done.call()
		return
	m.call("show_privacy_options", on_done)
