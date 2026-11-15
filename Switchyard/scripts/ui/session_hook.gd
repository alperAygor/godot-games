class_name SessionHook
extends RefCounted

## Saha görünümünün TEK bağlandığı yer: Game (oyun) ve Home (canlı arka plan, `start_demo`) oturumu buradan alır.
## Şimdilik kabuğun sahte sahası; gerçek görünüm gelince yalnız `create()` gövdesi `return YardSession.new()` olur.
# KANCA: gerçek saha görünümü (YardSession) burada bağlanır
static func create() -> LevelSession:
	return StubSession.new()
