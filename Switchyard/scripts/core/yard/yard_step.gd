class_name YardStep
extends RefCounted
## Bir sürüş adımının sonucu (docs/CORE_API.md §2).
## Adım "etkili"dir: katar ilerlediyse YA DA bir şey bağlandıysa (tampona dayalı vagona bağlanma gibi).
## Etkili adım sürüşün parçasıdır ve hamle sayımında aynı yöndeki sürüşü sürdürür (docs/YARD.md §2).

## Katar bir hücre ilerledi mi.
var moved: bool = false
## Bu adımda katara bağlanan araçlar (canlandırma, ses).
var coupled: PackedStringArray = PackedStringArray()
## "" | "buffer" | "self" | "foul" | "gate" | "traction"
var blocked: String = ""
## Araç kimliği -> PackedInt32Array([eski hücre, yeni hücre]).
var moves: Dictionary = {}


func effective() -> bool:
	return moved or not coupled.is_empty()
