class_name MenuScreen
extends RefCounted
## Menü ekran modülünün tabanı. Her ekran (ana menü, hangar, atölye, ayarlar, nasıl oynanır, duraklatma, kartlar, oyun sonu)
## kendi dosyasında bu sınıfı genişletir. `Menus` (menus.gd) modülleri kurar ve genel API'yi onlara yönlendirir.
##
## Sözleşme:
##  * `build()`   dil değişiminde de çağrılır: ekranın KÖK düğümünü `host.make_screen(id, dim)` ile oluşturur (kimlik = ekran adı).
##  * `on_open()` `host.open_sub()` ekranı göstermeden hemen önce çağırır (içeriği tazele).
##  * Durum modülün kendi alanlarında tutulur; modül yeniden kurulunca (dil) sıfırlanır.
##  * Başka ekranın düğümüne doğrudan uzanma: gerekirse `host` üzerindeki yönlendirme çağrıları (ör. `host.sync_main_cores()`).

var host: MenuHost
var root: Control


func _init(menu_host: MenuHost) -> void:
	host = menu_host


func build() -> void:
	pass


func on_open() -> void:
	pass
