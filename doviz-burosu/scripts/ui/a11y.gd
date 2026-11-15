class_name A11y
extends RefCounted
## Erişilebilirlik ayarlarının çalışma zamanı okuyucusu ve uygulayıcısı. Kural `Accessibility`'de (saf), tema türetme `ThemeVariants`'ta.
## Ayarlar SettingsManager "access" bölümünde: text_size ("normal"/"large"), color_blind, reduced_motion.
## Ekranlar yazı boyutunu elle çiziyorsa `A11y.scaled(boyut)`, renkle anlattıklarının yanına `A11y.mark(...)`/`A11y.color(...)` kullanır.


static func _settings() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("SettingsManager") if Engine.get_main_loop() != null else null


static func text_size() -> String:
	var settings := _settings()
	return Accessibility.sanitize_text_size(settings.get_value("access", "text_size") if settings != null else "normal")


static func text_scale() -> float:
	return Accessibility.text_scale(text_size())


## Elle çizilen/sabit yazı boyutunu seçili yazı boyutuna göre ölçekler.
static func scaled(base: int) -> int:
	return Accessibility.scaled_size(base, text_size())


static func color_blind() -> bool:
	var settings := _settings()
	return settings != null and bool(settings.get_value("access", "color_blind"))


## Hareketi azalt: ekran sallantısı, titreme (floresan), parlama, pop/kayma animasyonları kapanır.
static func reduced_motion() -> bool:
	var settings := _settings()
	return settings != null and bool(settings.get_value("access", "reduced_motion"))


## Renk körü kipinde uyarlanmış renk (kip kapalıysa aynı renk).
static func color(base: Color) -> Color:
	return Accessibility.adapt(base, color_blind())


## Renk körü kipinde "[+] metin" gibi işaretli metin (kip kapalıysa aynı metin).
static func mark(kind: String, text: String) -> String:
	return Accessibility.marked(kind, text, color_blind())


## Seçili ayarlara göre kök pencerenin temasını kurar. Ana temadan türetir; ikisi de varsayılansa temayı proje temasına bırakır.
static func apply(tree: SceneTree) -> void:
	if tree == null:
		return
	var base: Theme = ThemeDB.get_project_theme()
	if base == null:
		base = load("res://assets/theme/main_theme.tres") as Theme
	var variant := ThemeVariants.build(base, text_size(), color_blind())
	tree.root.theme = null if variant == base else variant
