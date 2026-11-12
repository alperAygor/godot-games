class_name ZoneCycle
extends RefCounted

## Saf mantık: sonsuz modda level -> çevre bölgesi (zone) eşlemesi. Her `LEVELS_PER_ZONE`
## level'da bölge değişir; bölge sayısı bitince başa döner. Sözleşme: PROJECT_SPEC §14.

const LEVELS_PER_ZONE: int = 5


## Level'ın bölge sırası (0'dan). `zone_count <= 0` güvenli biçimde 0 verir.
static func zone_for(level: int, zone_count: int) -> int:
	if zone_count <= 0:
		return 0
	return ((maxi(level, 1) - 1) / LEVELS_PER_ZONE) % zone_count


## Bu level yeni bir bölgenin ilk level'ı mı (level 1 sayılmaz: oyun zaten ilk bölgede başlar).
static func is_zone_start(level: int) -> bool:
	return level > 1 and (level - 1) % LEVELS_PER_ZONE == 0
