extends TestCase

## Reklam yerleşimi (Google Play/AdMob politikası): geçiş reklamı yalnız seviye geçişinde
## (sonuç sayfası "Devam"ı -> EcoFlow.maybe_interstitial); açılışta/çıkışta/oynanış sırasında yok.
## Yapısal sınır kaynak taramasıyla sabitlenir: yeni bir çağrı noktası eklenirse bu test kırılır ve
## yerleşim bilinçli olarak yeniden gözden geçirilir.

const SCRIPTS_DIR: String = "res://scripts"
## `AdManager.show_interstitial(` çağrısına izin verilen TEK dosya.
const INTERSTITIAL_CALLERS: Array[String] = ["res://scripts/ui/eco_flow.gd"]
## `maybe_interstitial(` çağrılan dosyalar (tanım dosyası hariç): yalnız oyun sahnesi (seviye sonu "Devam").
const MAYBE_CALLERS: Array[String] = ["res://scripts/ui/game.gd"]
const DEFINITION_FILES: Array[String] = ["res://scripts/ui/eco_flow.gd", "res://scripts/autoload/AdManager.gd"]


func _gd_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_gd_files(dir_path.path_join(sub)))
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append(dir_path.path_join(file_name))
	return found


func _files_containing(needle: String) -> Array[String]:
	var hits: Array[String] = []
	for path: String in _gd_files(SCRIPTS_DIR):
		if FileAccess.get_file_as_string(path).contains(needle):
			hits.append(path)
	return hits


func test_interstitial_is_requested_from_one_place_only() -> void:
	for path: String in _files_containing("AdManager.show_interstitial("):
		assert_true(INTERSTITIAL_CALLERS.has(path), "beklenmeyen geçiş reklamı çağrısı: %s" % path)
	assert_false(_files_containing("AdManager.show_interstitial(").is_empty(), "çağrı noktası kayboldu")


func test_level_transition_hook_is_called_only_from_game_scene() -> void:
	for path: String in _files_containing("maybe_interstitial("):
		if DEFINITION_FILES.has(path):
			continue
		assert_true(MAYBE_CALLERS.has(path), "beklenmeyen maybe_interstitial çağrısı: %s" % path)


func test_no_ads_on_boot_menu_or_exit_scripts() -> void:
	# Açılış/menü/çıkış katmanlarında hiçbir reklam çağrısı olmamalı.
	for path: String in ["res://scripts/ui/boot.gd", "res://scripts/ui/menu.gd", "res://scripts/ui/home.gd",
			"res://scripts/ui/pause_sheet.gd", "res://scripts/autoload/GameManager.gd"]:
		var source: String = FileAccess.get_file_as_string(path)
		assert_false(source.contains("show_interstitial") or source.contains("maybe_interstitial")
			or source.contains("show_rewarded"), "%s reklam çağırıyor" % path)


func test_interstitial_never_pays_a_reward_and_never_stacks() -> void:
	var manager: Node = autoload_node("AdManager")
	if manager == null:
		return
	var provider: MockAdsProvider = MockAdsProvider.new()
	manager.call("set_provider", provider)
	manager.call("reset_session_limits")
	var rewards: Array[bool] = []
	manager.connect("rewarded_finished", func(_placement: int, success: bool) -> void: rewards.append(success))
	var first: bool = bool(manager.call("show_interstitial"))
	var second: bool = bool(manager.call("show_interstitial"))
	assert_false(first and second, "ardışık iki geçiş reklamı aynı anda başlamaz")
	assert_true(rewards.is_empty(), "geçiş reklamı ödül sinyali vermez")
