class_name StoreConfig
extends RefCounted

## Mağaza/yayın ayarları (`data/store.json`) — şimdilik yalnız gizlilik politikası adresi.
## Tek kaynak: sahibin barındırdığı URL yalnız `data/store.json` içinde değişir (Play Console alanıyla AYNI olmalı).
## Yer tutucu adres (`example.invalid`) hata ayıklama sürümünde düğmeyi gösterir (ekranı görmek için),
## yayın sürümünde GİZLER ve `tools/release_check.sh` başarısız olur: gerçek adres olmadan yayın çıkmaz.

const PATH: String = "res://data/store.json"
const KEY_PRIVACY: String = "privacy_policy_url"
const PLACEHOLDER_MARKER: String = "example.invalid"


static func privacy_policy_url() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		return String((parsed as Dictionary).get(KEY_PRIVACY, "")).strip_edges()
	return ""


## Düğme görünür mü: adres https ile başlamalı; yer tutucu yalnız hata ayıklamada görünür.
static func privacy_link_visible(url: String, debug_build: bool) -> bool:
	if not url.begins_with("https://"):
		return false
	return debug_build or not url.contains(PLACEHOLDER_MARKER)


static func open_privacy_policy() -> void:
	var url: String = privacy_policy_url()
	if privacy_link_visible(url, OS.is_debug_build()):
		OS.shell_open(url)
