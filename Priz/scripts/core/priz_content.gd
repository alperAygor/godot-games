class_name PrizContent
extends RefCounted
## Öğe kayıt defteri + cihaz kataloğu paketi. Ana iş parçacığında bir kez kurulur:
##   var content := PrizContent.load_default()
## Sonra tahta, çözücü, üretici ve günlük seviye bu paketi okur (salt okunur paylaşılır).

var registry: PrizElementRegistry
var catalog: PrizCatalog


static func load_default() -> PrizContent:
	var content: PrizContent = PrizContent.new()
	content.registry = PrizElementRegistry.create_default()
	content.catalog = PrizCatalog.create_default()
	return content


static func create(element_registry: PrizElementRegistry, device_catalog: PrizCatalog) -> PrizContent:
	var content: PrizContent = PrizContent.new()
	content.registry = element_registry
	content.catalog = device_catalog
	return content
