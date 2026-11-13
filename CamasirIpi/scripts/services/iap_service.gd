class_name IapService
extends Node

## Satın alma servisi: sağlayıcıyı seçer, sahipliği `Progress`e (modül "shop") yazar ve açılışta
## mağazadan yeniden doğrular. Autoload DEĞİLDİR: `IapService.ensure(tree)` düğümü kökün altına
## bir kez ekler (açılışta Boot, mağaza açılırken Shop çağırır).
## `Progress` düğümü yol ile bulunur (MetaStore gibi): testler kendi örneğini verebilir.

const PROGRESS_PATH: NodePath = ^"/root/Progress"
const NODE_NAME: String = "IapService"

## Sahiplik ya da fiyat değişti (mağaza sayfası ve ayarlar yenilensin).
signal state_changed
## Satın alma başarısız (iptal dahil); sebep kodu IapProvider.REASON_*.
signal purchase_failed(reason: String)
## `restore_purchases()` bitti; `found` = geri yüklenen ürün var mı.
signal restore_done(found: bool)

static var _instance: IapService = null

var provider: IapProvider = null
var progress: Node = null
var _manual_restore: bool = false


## Düğüm yoksa oluşturur ve ağaca ekler; varsa onu döner.
static func ensure(tree: SceneTree) -> IapService:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var existing: Node = tree.root.get_node_or_null(NODE_NAME) if tree != null else null
	if existing is IapService:
		_instance = existing as IapService
		return _instance
	var service: IapService = IapService.new()
	service.name = NODE_NAME
	_instance = service
	if tree != null:
		# Ağaç kurulurken çağrılabilir (Boot._ready): ekleme kare sonuna ertelenir.
		tree.root.add_child.call_deferred(service)
	return service


## Seçim: eklenti varsa Play Faturalandırma; yoksa hata ayıklama sürümünde sahte mağaza;
## yayın sürümünde "mağaza yok" (satın alma düğmesi devre dışı kalır, sahte başarı VERİLMEZ).
static func make_default_provider() -> IapProvider:
	if PlayBillingProvider.plugin_present():
		return PlayBillingProvider.new()
	if OS.is_debug_build():
		return MockIapProvider.new()
	return IapProvider.new()


func _ready() -> void:
	_bind_progress()
	if provider == null:
		set_provider(make_default_provider())


func set_provider(new_provider: IapProvider) -> void:
	if provider != null:
		provider.purchase_succeeded.disconnect(_on_purchase_succeeded)
		provider.purchase_failed.disconnect(_on_purchase_failed)
		provider.restore_finished.disconnect(_on_restore_finished)
		provider.prices_changed.disconnect(_on_prices_changed)
	provider = new_provider
	provider.purchase_succeeded.connect(_on_purchase_succeeded)
	provider.purchase_failed.connect(_on_purchase_failed)
	provider.restore_finished.connect(_on_restore_finished)
	provider.prices_changed.connect(_on_prices_changed)
	provider.initialize()
	# Açılış doğrulaması: mağaza hazırsa sahiplik yeniden sorulur (sessiz; arayüz göstermez).
	if provider.is_available():
		provider.restore()


## `Progress` düğümünü bulur (enjekte edilmemişse). `ensure` düğümü ağaca ertelenmiş ekler; mağaza
## `_ready`den ÖNCE sahipliği sorarsa bile doğru yanıt versin diye burada kökten aranır.
func _bind_progress() -> void:
	if progress != null:
		return
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop != null:
		progress = loop.root.get_node_or_null(PROGRESS_PATH)


func remove_ads_owned() -> bool:
	_bind_progress()
	return progress != null and bool(progress.call("remove_ads_owned"))


func store_available() -> bool:
	return provider != null and provider.is_available()


func price_text() -> String:
	return provider.price_text(IapProvider.PRODUCT_REMOVE_ADS) if provider != null else ""


func buy_remove_ads() -> void:
	if remove_ads_owned():
		return
	if not store_available():
		purchase_failed.emit(IapProvider.REASON_UNAVAILABLE)
		return
	provider.purchase(IapProvider.PRODUCT_REMOVE_ADS)


## "Satın alımları geri yükle" bağlantısı.
func restore_purchases() -> void:
	if not store_available():
		restore_done.emit(false)
		return
	_manual_restore = true
	provider.restore()


func _on_purchase_succeeded(product_id: String) -> void:
	if product_id != IapProvider.PRODUCT_REMOVE_ADS:
		return
	var first_time: bool = not remove_ads_owned()
	_set_owned(true)
	if first_time:
		AnalyticsLog.record("remove_ads_purchased", {"price": price_text()})
		AnalyticsLog.record("purchase", {"item": product_id, "price": price_text(), "currency": "store"})
	state_changed.emit()


func _on_purchase_failed(_product_id: String, reason: String) -> void:
	purchase_failed.emit(reason)


func _on_restore_finished(owned_ids: PackedStringArray, ok: bool) -> void:
	var manual: bool = _manual_restore
	_manual_restore = false
	var owned: bool = owned_ids.has(IapProvider.PRODUCT_REMOVE_ADS)
	if owned:
		_set_owned(true)
	elif ok and provider.is_authoritative():
		# Mağaza sorguyu BAŞARIYLA yanıtladı ve ürün yok: iade edilmiş/başka hesap. Kayıt temizlenir.
		_set_owned(false)
	state_changed.emit()
	if manual:
		restore_done.emit(owned)


func _on_prices_changed() -> void:
	state_changed.emit()


func _set_owned(owned: bool) -> void:
	_bind_progress()
	if progress != null:
		progress.call("set_remove_ads_owned", owned)
